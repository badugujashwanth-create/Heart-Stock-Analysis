from __future__ import annotations

import hashlib
import json
import threading
from collections import OrderedDict
from typing import Any

from app.config import Settings

from .constants import SAFE_MEDICAL_DISCLAIMER
from .openai_provider import OpenAIProvider
from .provider import AIProvider, AIProviderError
from .rules_provider import RulesAIProvider
from .schemas import (
    AIChatRequest,
    AIChatResponse,
    AIPlanPreview,
    AIPlanRequest,
    AIPlanResponse,
)


class AIService:
    def __init__(
        self,
        *,
        primary_provider: AIProvider,
        fallback_provider: AIProvider,
        cache_size: int = 64,
    ) -> None:
        self._primary_provider = primary_provider
        self._fallback_provider = fallback_provider
        self._cache_size = cache_size
        self._plan_cache: OrderedDict[str, AIPlanResponse] = OrderedDict()
        self._cache_lock = threading.Lock()

    @classmethod
    def from_settings(cls, settings: Settings) -> AIService:
        fallback = RulesAIProvider()
        if settings.ai_provider == "openai" and settings.openai_api_key:
            primary: AIProvider = OpenAIProvider(
                api_key=settings.openai_api_key,
                model=settings.openai_model,
                base_url=settings.openai_base_url,
                timeout_seconds=settings.openai_timeout_seconds,
                provider_name="OpenAI",
            )
        elif settings.ai_provider == "llama_cpp":
            primary = OpenAIProvider(
                api_key=None,
                model=settings.llama_cpp_model,
                base_url=settings.llama_cpp_base_url,
                timeout_seconds=settings.llama_cpp_timeout_seconds,
                provider_name="llama.cpp",
                require_api_key=False,
            )
        else:
            primary = fallback

        return cls(primary_provider=primary, fallback_provider=fallback)

    def generate_plan(self, request_data: AIPlanRequest) -> AIPlanResponse:
        payload_for_hash: dict[str, Any] = request_data.model_dump(mode="json")
        cache_key = self._hash_payload(payload_for_hash)
        with self._cache_lock:
            cached = self._plan_cache.get(cache_key)
            if cached is not None:
                return cached.model_copy(deep=True)

        plan = self._generate_with_fallback(request_data)
        plan = self._ensure_disclaimer(plan)

        with self._cache_lock:
            self._plan_cache[cache_key] = plan.model_copy(deep=True)
            self._plan_cache.move_to_end(cache_key)
            while len(self._plan_cache) > self._cache_size:
                self._plan_cache.popitem(last=False)
        return plan.model_copy(deep=True)

    def chat(self, request_data: AIChatRequest) -> AIChatResponse:
        try:
            response = self._primary_provider.chat(request_data)
        except AIProviderError:
            response = self._fallback_provider.chat(request_data)

        disclaimer = response.disclaimer if isinstance(response.disclaimer, str) else ""
        if not disclaimer.strip():
            response = response.model_copy(update={"disclaimer": SAFE_MEDICAL_DISCLAIMER})
        answer = response.answer if isinstance(response.answer, str) else ""
        if SAFE_MEDICAL_DISCLAIMER.lower() not in answer.lower():
            merged_answer = answer.rstrip()
            if merged_answer:
                merged_answer = f"{merged_answer}\n\n{SAFE_MEDICAL_DISCLAIMER}"
            else:
                merged_answer = SAFE_MEDICAL_DISCLAIMER
            response = response.model_copy(
                update={"answer": merged_answer}
            )
        return response

    def preview(self, plan: AIPlanResponse) -> AIPlanPreview:
        return AIPlanPreview(
            summary=plan.summary,
            top_priorities=[
                {"title": item.title, "why": item.why}
                for item in plan.top_priorities[:3]
            ],
            disclaimer=plan.disclaimer or SAFE_MEDICAL_DISCLAIMER,
        )

    def _generate_with_fallback(self, request_data: AIPlanRequest) -> AIPlanResponse:
        try:
            return self._primary_provider.generate_plan(request_data)
        except AIProviderError:
            return self._fallback_provider.generate_plan(request_data)

    def _ensure_disclaimer(self, plan: AIPlanResponse) -> AIPlanResponse:
        disclaimer = plan.disclaimer if isinstance(plan.disclaimer, str) else ""
        if disclaimer.strip():
            return plan
        return plan.model_copy(update={"disclaimer": SAFE_MEDICAL_DISCLAIMER})

    def _hash_payload(self, payload: dict[str, Any]) -> str:
        encoded = json.dumps(payload, sort_keys=True, ensure_ascii=False).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest()
