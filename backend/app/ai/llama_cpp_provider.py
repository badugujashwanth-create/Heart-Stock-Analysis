from __future__ import annotations

import json
import threading
from copy import deepcopy
from functools import lru_cache
from typing import Any

from pydantic import BaseModel

from .constants import AI_SYSTEM_PROMPT_CHAT, AI_SYSTEM_PROMPT_PLAN, SAFE_MEDICAL_DISCLAIMER
from .openai_provider import JSONDict, OpenAIProvider
from .provider import AIProviderError
from .schemas import AIChatRequest, AIChatResponse, AIPlanRequest, AIPlanResponse


@lru_cache(maxsize=8)
def _cached_schema(model_cls: type[BaseModel]) -> dict[str, Any]:
    raw_schema = deepcopy(model_cls.model_json_schema())
    defs = deepcopy(raw_schema.pop("$defs", {}))
    return _inline_json_refs(raw_schema, defs)


def _inline_json_refs(node: Any, defs: dict[str, Any]) -> Any:
    if isinstance(node, dict):
        ref = node.get("$ref")
        if isinstance(ref, str) and ref.startswith("#/$defs/"):
            ref_name = ref.removeprefix("#/$defs/")
            resolved = deepcopy(defs[ref_name])
            merged = _inline_json_refs(resolved, defs)
            extras = {k: v for k, v in node.items() if k != "$ref"}
            if extras:
                if not isinstance(merged, dict):
                    raise ValueError("Resolved JSON schema reference must be an object")
                merged.update(_inline_json_refs(extras, defs))
            return merged

        flattened: dict[str, Any] = {}
        for key, value in node.items():
            if key in {"$defs", "title", "default", "examples"}:
                continue
            flattened[key] = _inline_json_refs(value, defs)

        if flattened.get("type") == "object" and "additionalProperties" not in flattened:
            flattened["additionalProperties"] = False
        return flattened

    if isinstance(node, list):
        return [_inline_json_refs(item, defs) for item in node]

    return node


class LlamaCppProvider(OpenAIProvider):
    def __init__(
        self,
        *,
        model: str,
        base_url: str,
        timeout_seconds: int,
    ) -> None:
        super().__init__(
            api_key="no-key",
            model=model,
            base_url=base_url,
            timeout_seconds=timeout_seconds,
            provider_name="llama.cpp",
            require_api_key=False,
        )
        self._schema_enabled = True
        self._schema_lock = threading.Lock()

    def generate_plan(self, request_data: AIPlanRequest) -> AIPlanResponse:
        payload = self._build_payload(
            system_prompt=AI_SYSTEM_PROMPT_PLAN,
            user_content={
                "task": "Generate a safe lifestyle plan JSON for this context.",
                "required_output_keys": [
                    "summary",
                    "top_priorities",
                    "diet_plan",
                    "exercise_plan",
                    "habits",
                    "red_flags",
                    "disclaimer",
                ],
                "context": request_data.model_dump(mode="json"),
            },
            response_model=AIPlanResponse,
        )
        response_json = self._post_with_schema_fallback(payload)
        content = self._extract_content(response_json)
        plan = self._parse_model_response(content, AIPlanResponse, "AI plan")

        if not plan.disclaimer.strip():
            plan = plan.model_copy(update={"disclaimer": SAFE_MEDICAL_DISCLAIMER})
        return plan

    def chat(self, request_data: AIChatRequest) -> AIChatResponse:
        payload = self._build_payload(
            system_prompt=AI_SYSTEM_PROMPT_CHAT,
            user_content={
                "message": request_data.message,
                "context": request_data.model_dump(mode="json"),
            },
            response_model=AIChatResponse,
        )
        response_json = self._post_with_schema_fallback(payload)
        content = self._extract_content(response_json)
        chat = self._parse_model_response(content, AIChatResponse, "AI chat")

        if not chat.disclaimer.strip():
            chat = chat.model_copy(update={"disclaimer": SAFE_MEDICAL_DISCLAIMER})
        if SAFE_MEDICAL_DISCLAIMER.lower() not in chat.answer.lower():
            answer = chat.answer.rstrip()
            merged_answer = (
                f"{answer}\n\n{SAFE_MEDICAL_DISCLAIMER}".strip()
                if answer
                else SAFE_MEDICAL_DISCLAIMER
            )
            chat = chat.model_copy(update={"answer": merged_answer})
        return chat

    def _build_payload(
        self,
        *,
        system_prompt: str,
        user_content: dict[str, Any],
        response_model: type[BaseModel],
    ) -> JSONDict:
        return {
            "model": self._model,
            "temperature": 0.2,
            "response_format": self._response_format(response_model),
            "messages": [
                {"role": "system", "content": system_prompt},
                {
                    "role": "user",
                    "content": json.dumps(user_content, ensure_ascii=False),
                },
            ],
        }

    def _response_format(self, response_model: type[BaseModel]) -> JSONDict:
        with self._schema_lock:
            if not self._schema_enabled:
                return {"type": "json_object"}

        return {
            "type": "json_schema",
            "schema": deepcopy(_cached_schema(response_model)),
        }

    def _post_with_schema_fallback(self, payload: JSONDict) -> JSONDict:
        try:
            return self._post_json(payload)
        except AIProviderError as exc:
            if not self._should_retry_without_schema(payload, exc):
                raise

        with self._schema_lock:
            self._schema_enabled = False

        fallback_payload = dict(payload)
        fallback_payload["response_format"] = {"type": "json_object"}
        return self._post_json(fallback_payload)

    @staticmethod
    def _should_retry_without_schema(payload: JSONDict, exc: AIProviderError) -> bool:
        response_format = payload.get("response_format")
        if not isinstance(response_format, dict):
            return False
        if response_format.get("type") != "json_schema":
            return False

        message = str(exc).lower()
        return (
            "http error 400" in message
            or "response_format" in message
            or "json_schema" in message
            or "schema" in message
        )
