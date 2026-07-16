import json
from typing import Any

from openai import OpenAI

from app.agent.config import LLMSettings
from app.agent.context import ToolContext
from app.agent.enrichment import enrich_packing_response
from app.agent.exceptions import AgentResponseError, LLMConfigurationError, ParseError
from app.agent.parser import clean_model_output, parse_packing_response
from app.agent.prompts import build_system_prompt
from app.agent.tools import TOOL_DEFINITIONS, execute_tool
from app.models.chat import PackingResponse
from app.models.profile import TravelerProfile
from app.observability import (
    BAGGAGE_WARNINGS,
    INVALID_RESPONSES,
    LLM_DURATION,
    LLM_ERRORS,
    LLM_REQUESTS,
    Timer,
    span,
)


class AgentService:
    MAX_TOOL_ROUNDS = 5
    MAX_PARSE_ATTEMPTS = 3

    def __init__(
        self,
        settings: LLMSettings | None = None,
        client: OpenAI | None = None,
    ) -> None:
        self.settings = settings or LLMSettings.from_env()
        self._client = client

    def _get_client(self) -> OpenAI:
        if self._client is not None:
            return self._client
        return self.settings.create_client()

    @staticmethod
    def _assistant_message_to_dict(message: Any) -> dict[str, Any]:
        payload: dict[str, Any] = {"role": "assistant", "content": message.content}
        if message.tool_calls:
            payload["tool_calls"] = [
                {
                    "id": tool_call.id,
                    "type": "function",
                    "function": {
                        "name": tool_call.function.name,
                        "arguments": tool_call.function.arguments,
                    },
                }
                for tool_call in message.tool_calls
            ]
        return payload

    def _enrich_response(
        self,
        response: PackingResponse,
        context: ToolContext,
    ) -> PackingResponse:
        with span("enrichment.deterministic", {"language": response.language}):
            enriched = enrich_packing_response(
                response=response,
                profile=context.traveler_profile,
                collected_baggage_warnings=context.collected_baggage_warnings,
                rules_disclaimer=context.rules_disclaimer,
                weather_response=context.weather_response,
            )
        if enriched.baggage_warnings:
            BAGGAGE_WARNINGS.inc(len(enriched.baggage_warnings))
        return enriched

    async def _parse_with_retries(
        self,
        client: OpenAI,
        messages: list[dict[str, Any]],
        content: str,
        context: ToolContext,
    ) -> PackingResponse:
        current_content = content

        for attempt in range(self.MAX_PARSE_ATTEMPTS):
            try:
                with span("parser.packing_response", {"attempt": attempt + 1}):
                    parsed = parse_packing_response(current_content)
                return self._enrich_response(parsed, context)
            except ParseError as exc:
                INVALID_RESPONSES.inc()
                if attempt >= self.MAX_PARSE_ATTEMPTS - 1:
                    raise AgentResponseError(
                        f"Invalid agent response after {self.MAX_PARSE_ATTEMPTS} attempts: {exc}"
                    ) from exc

                messages.append(
                    {
                        "role": "assistant",
                        "content": clean_model_output(current_content),
                    }
                )
                messages.append(
                    {
                        "role": "user",
                        "content": (
                            "Your previous answer was invalid. "
                            f"Error: {exc}. "
                            "Return ONLY valid JSON matching the required schema. "
                            "Do not include markdown fences or explanations."
                        ),
                    }
                )

                correction = self._llm_create(client, messages)
                current_content = correction.choices[0].message.content or ""

        raise AgentResponseError("Unable to parse agent response.")

    def _llm_create(self, client: OpenAI, messages: list[dict[str, Any]], **kwargs: Any):
        timer = Timer()
        try:
            with span("llm.chat.completions", {"status": "started"}):
                response = client.chat.completions.create(
                    model=self.settings.model,
                    messages=messages,
                    **kwargs,
                )
            LLM_REQUESTS.labels(status="ok").inc()
            LLM_DURATION.observe(timer.seconds())
            return response
        except Exception as exc:
            LLM_REQUESTS.labels(status="error").inc()
            LLM_ERRORS.labels(error_type=type(exc).__name__).inc()
            LLM_DURATION.observe(timer.seconds())
            raise

    async def chat(
        self,
        message: str,
        traveler_profile: TravelerProfile | None = None,
    ) -> PackingResponse:
        self.settings.require_configured()
        client = self._get_client()
        context = ToolContext(traveler_profile=traveler_profile)

        messages: list[dict[str, Any]] = [
            {"role": "system", "content": build_system_prompt()},
            {"role": "user", "content": message},
        ]

        for _ in range(self.MAX_TOOL_ROUNDS):
            response = self._llm_create(
                client,
                messages,
                tools=TOOL_DEFINITIONS,
                tool_choice="auto",
            )
            assistant_message = response.choices[0].message

            if assistant_message.tool_calls:
                messages.append(self._assistant_message_to_dict(assistant_message))
                for tool_call in assistant_message.tool_calls:
                    tool_result = await execute_tool(
                        tool_call.function.name,
                        tool_call.function.arguments,
                        context,
                    )
                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": tool_call.id,
                            "content": tool_result,
                        }
                    )
                continue

            if assistant_message.content:
                return await self._parse_with_retries(
                    client,
                    messages,
                    assistant_message.content,
                    context,
                )

        raise AgentResponseError(
            "Agent exceeded maximum tool rounds without a final answer."
        )
