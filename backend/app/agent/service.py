import asyncio
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
    # Keep the tool loop short: OpenShift routes on AWS Classic LB often idle-out
    # near ~60s even when haproxy.router.openshift.io/timeout is higher.
    MAX_TOOL_ROUNDS = 6
    MAX_PARSE_ATTEMPTS = 3
    MAX_COMPLETION_TOKENS = 1280
    ESSENTIAL_TOOLS = frozenset({"get_weather", "baggage_rules"})

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
    def _tools_for_request(
        traveler_profile: TravelerProfile | None,
    ) -> list[dict[str, Any]]:
        if traveler_profile is not None:
            return TOOL_DEFINITIONS
        return [
            tool
            for tool in TOOL_DEFINITIONS
            if tool["function"]["name"] != "traveler_profile"
        ]

    @staticmethod
    def _tool_cache_key(name: str, arguments: str | None) -> tuple[str, str]:
        raw = arguments or "{}"
        try:
            normalized = json.dumps(
                json.loads(raw), sort_keys=True, separators=(",", ":")
            )
        except json.JSONDecodeError:
            normalized = raw
        return (name, normalized)

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

                correction = await self._llm_create(
                    client,
                    messages,
                    max_tokens=self.MAX_COMPLETION_TOKENS,
                )
                current_content = correction.choices[0].message.content or ""

        raise AgentResponseError("Unable to parse agent response.")

    async def _llm_create(
        self, client: OpenAI, messages: list[dict[str, Any]], **kwargs: Any
    ):
        # Run the sync OpenAI client off the event loop so /health and /ready
        # stay responsive during long model/tool rounds.
        timer = Timer()
        kwargs.setdefault("max_tokens", self.MAX_COMPLETION_TOKENS)
        try:
            with span("llm.chat.completions", {"status": "started"}):
                response = await asyncio.to_thread(
                    client.chat.completions.create,
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
            # Surface model/gateway 4xx as agent errors (HTTP 502) instead of unhandled 500.
            raise AgentResponseError(
                f"LLM request failed: {type(exc).__name__}: {str(exc)[:240]}"
            ) from exc

    async def chat(
        self,
        message: str,
        traveler_profile: TravelerProfile | None = None,
    ) -> PackingResponse:
        self.settings.require_configured()
        client = self._get_client()
        context = ToolContext(traveler_profile=traveler_profile)
        tools = self._tools_for_request(traveler_profile)
        tool_cache: dict[tuple[str, str], str] = {}
        completed_tools: set[str] = set()
        forced_final_nudge = False

        messages: list[dict[str, Any]] = [
            {"role": "system", "content": build_system_prompt()},
            {"role": "user", "content": message},
        ]

        for _ in range(self.MAX_TOOL_ROUNDS):
            essentials_ready = self.ESSENTIAL_TOOLS.issubset(completed_tools)
            if essentials_ready:
                if not forced_final_nudge:
                    messages.append(
                        {
                            "role": "user",
                            "content": (
                                "You already have weather and baggage tool results. "
                                "Return ONLY valid JSON matching the required schema now. "
                                "Do not call tools."
                            ),
                        }
                    )
                    forced_final_nudge = True
                response = await self._llm_create(client, messages)
            else:
                create_kwargs: dict[str, Any] = {
                    "tools": tools,
                    "tool_choice": "auto",
                    "parallel_tool_calls": False,
                }
                try:
                    response = await self._llm_create(
                        client,
                        messages,
                        **create_kwargs,
                    )
                except Exception as exc:
                    # Some gateways reject the parallel_tool_calls parameter.
                    err_text = str(exc).lower()
                    if "parallel_tool_calls" in err_text or "unexpected keyword" in err_text:
                        create_kwargs.pop("parallel_tool_calls", None)
                        response = await self._llm_create(
                            client,
                            messages,
                            **create_kwargs,
                        )
                    elif "single tool" in err_text:
                        messages.append(
                            {
                                "role": "user",
                                "content": (
                                    "Call only one tool at a time. "
                                    "Prefer get_weather first, then baggage_rules, then final JSON."
                                ),
                            }
                        )
                        response = await self._llm_create(
                            client,
                            messages,
                            **create_kwargs,
                        )
                    else:
                        raise
            assistant_message = response.choices[0].message

            if assistant_message.tool_calls and not essentials_ready:
                messages.append(self._assistant_message_to_dict(assistant_message))

                async def _run_one(tool_call: Any) -> tuple[Any, str, str]:
                    cache_key = self._tool_cache_key(
                        tool_call.function.name,
                        tool_call.function.arguments,
                    )
                    if cache_key in tool_cache:
                        return tool_call, tool_cache[cache_key], tool_call.function.name
                    result = await execute_tool(
                        tool_call.function.name,
                        tool_call.function.arguments,
                        context,
                    )
                    tool_cache[cache_key] = result
                    return tool_call, result, tool_call.function.name

                executed = await asyncio.gather(
                    *[_run_one(tc) for tc in assistant_message.tool_calls]
                )
                for tool_call, tool_result, tool_name in executed:
                    completed_tools.add(tool_name)
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

        # Force a schema JSON answer without further tool calls (small models).
        messages.append(
            {
                "role": "user",
                "content": (
                    "Stop calling tools. Using the tool results already provided, "
                    "return ONLY valid JSON matching the required schema. "
                    "No markdown fences or explanations."
                ),
            }
        )
        final = await self._llm_create(client, messages)
        final_content = final.choices[0].message.content or ""
        if final_content:
            return await self._parse_with_retries(
                client,
                messages,
                final_content,
                context,
            )

        raise AgentResponseError(
            "Agent exceeded maximum tool rounds without a final answer."
        )
