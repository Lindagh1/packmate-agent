import json
from typing import Any

from openai import OpenAI

from app.agent.config import LLMSettings
from app.agent.exceptions import AgentResponseError, LLMConfigurationError, ParseError
from app.agent.parser import clean_model_output, parse_packing_response
from app.agent.prompts import build_system_prompt
from app.agent.tools import TOOL_DEFINITIONS, execute_tool
from app.models.chat import PackingResponse


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

    async def _parse_with_retries(
        self,
        client: OpenAI,
        messages: list[dict[str, Any]],
        content: str,
    ) -> PackingResponse:
        current_content = content

        for attempt in range(self.MAX_PARSE_ATTEMPTS):
            try:
                return parse_packing_response(current_content)
            except ParseError as exc:
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

                correction = client.chat.completions.create(
                    model=self.settings.model,
                    messages=messages,
                )
                current_content = correction.choices[0].message.content or ""

        raise AgentResponseError("Unable to parse agent response.")

    async def chat(self, message: str) -> PackingResponse:
        self.settings.require_configured()
        client = self._get_client()

        messages: list[dict[str, Any]] = [
            {"role": "system", "content": build_system_prompt()},
            {"role": "user", "content": message},
        ]

        for _ in range(self.MAX_TOOL_ROUNDS):
            response = client.chat.completions.create(
                model=self.settings.model,
                messages=messages,
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
                )

        raise AgentResponseError(
            "Agent exceeded maximum tool rounds without a final answer."
        )
