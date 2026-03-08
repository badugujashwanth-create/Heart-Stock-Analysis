from __future__ import annotations

from abc import ABC, abstractmethod

from .schemas import AIChatRequest, AIChatResponse, AIPlanRequest, AIPlanResponse


class AIProviderError(RuntimeError):
    pass


class AIProvider(ABC):
    @abstractmethod
    def generate_plan(self, request_data: AIPlanRequest) -> AIPlanResponse:
        raise NotImplementedError

    @abstractmethod
    def chat(self, request_data: AIChatRequest) -> AIChatResponse:
        raise NotImplementedError
