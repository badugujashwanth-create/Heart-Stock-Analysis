from __future__ import annotations

import json
from typing import Any, cast
from urllib import error, request

from .constants import AI_SYSTEM_PROMPT_CHAT, AI_SYSTEM_PROMPT_PLAN, SAFE_MEDICAL_DISCLAIMER
from .provider import AIProvider, AIProviderError
from .schemas import AIChatRequest, AIChatResponse, AIPlanRequest, AIPlanResponse

JSONDict = dict[str, Any]


class OpenAIProvider(AIProvider):
    def __init__(
        self,
        *,
        api_key: str | None,
        model: str,
        base_url: str,
        timeout_seconds: int,
        provider_name: str = "OpenAI",
        require_api_key: bool = True,
    ) -> None:
        normalized_api_key = (api_key or "").strip()
        if require_api_key and not normalized_api_key:
            raise AIProviderError(f"{provider_name} API key is required")

        base = base_url.rstrip("/")
        if base.endswith("/chat/completions"):
            self._endpoint = base
        else:
            if not base.endswith("/v1"):
                base = f"{base}/v1"
            self._endpoint = f"{base}/chat/completions"

        self._api_key = normalized_api_key
        self._model = model.strip() or "gpt-4.1-mini"
        self._timeout_seconds = timeout_seconds
        self._provider_name = provider_name

    def generate_plan(self, request_data: AIPlanRequest) -> AIPlanResponse:
        payload: JSONDict = {
            "model": self._model,
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": AI_SYSTEM_PROMPT_PLAN},
                {
                    "role": "user",
                    "content": json.dumps(
                        {
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
                        ensure_ascii=False,
                    ),
                },
            ],
        }
        response_json: JSONDict = self._post_json(payload)
        content = self._extract_content(response_json)

        try:
            raw = json.loads(content)
            plan = AIPlanResponse.model_validate(raw)
        except Exception as exc:  # pragma: no cover - defensive parsing
            raise AIProviderError(f"Invalid AI plan response: {exc}") from exc

        plan_disclaimer = plan.disclaimer if isinstance(plan.disclaimer, str) else ""
        if not plan_disclaimer.strip():
            plan = plan.model_copy(update={"disclaimer": SAFE_MEDICAL_DISCLAIMER})
        return plan

    def chat(self, request_data: AIChatRequest) -> AIChatResponse:
        payload: JSONDict = {
            "model": self._model,
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": AI_SYSTEM_PROMPT_CHAT},
                {
                    "role": "user",
                    "content": json.dumps(
                        {
                            "message": request_data.message,
                            "context": request_data.model_dump(mode="json"),
                        },
                        ensure_ascii=False,
                    ),
                },
            ],
        }
        response_json: JSONDict = self._post_json(payload)
        content = self._extract_content(response_json)

        try:
            raw = json.loads(content)
            chat = AIChatResponse.model_validate(raw)
        except Exception as exc:  # pragma: no cover - defensive parsing
            raise AIProviderError(f"Invalid AI chat response: {exc}") from exc

        chat_disclaimer = chat.disclaimer if isinstance(chat.disclaimer, str) else ""
        if not chat_disclaimer.strip():
            chat = chat.model_copy(update={"disclaimer": SAFE_MEDICAL_DISCLAIMER})
        answer = chat.answer if isinstance(chat.answer, str) else ""
        if SAFE_MEDICAL_DISCLAIMER.lower() not in answer.lower():
            chat = chat.model_copy(
                update={"answer": f"{answer.rstrip()}\n\n{SAFE_MEDICAL_DISCLAIMER}".strip()}
            )
        return chat

    def _post_json(self, payload: JSONDict) -> JSONDict:
        data = json.dumps(payload).encode("utf-8")
        req = request.Request(
            self._endpoint,
            data=data,
            method="POST",
            headers=self._headers(),
        )
        try:
            with request.urlopen(req, timeout=self._timeout_seconds) as resp:
                text = resp.read().decode("utf-8")
        except error.HTTPError as exc:  # pragma: no cover - depends on upstream
            body = exc.read().decode("utf-8", errors="ignore")
            raise AIProviderError(
                f"{self._provider_name} HTTP error {exc.code}: {body[:300]}"
            ) from exc
        except error.URLError as exc:  # pragma: no cover - depends on network
            raise AIProviderError(
                f"{self._provider_name} connection error: {exc.reason}"
            ) from exc

        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exc:  # pragma: no cover - defensive
            raise AIProviderError(
                f"{self._provider_name} returned non-JSON response"
            ) from exc
        if not isinstance(parsed, dict):
            raise AIProviderError(
                f"{self._provider_name} returned unexpected JSON format"
            )
        return cast(JSONDict, parsed)

    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"
        return headers

    def _extract_content(self, response_json: JSONDict) -> str:
        try:
            message = response_json["choices"][0]["message"]["content"]
        except Exception as exc:  # pragma: no cover - defensive
            raise AIProviderError(
                f"Missing choices/message content in {self._provider_name} response"
            ) from exc

        if isinstance(message, str):
            return message
        if isinstance(message, list):
            message_parts: list[object] = cast(list[object], message)
            texts: list[str] = []
            for part in message_parts:
                if not isinstance(part, dict):
                    continue
                part_dict: JSONDict = cast(JSONDict, part)
                if part_dict.get("type") != "text":
                    continue
                text_value = part_dict.get("text")
                if isinstance(text_value, str):
                    texts.append(text_value)
            if texts:
                return "\n".join(texts)
        raise AIProviderError(f"Unsupported {self._provider_name} content format")
