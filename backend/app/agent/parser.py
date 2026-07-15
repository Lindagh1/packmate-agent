import json
import re

from pydantic import ValidationError

from app.agent.exceptions import ParseError
from app.models.chat import PackingResponse

_THINKING_TAG_PATTERN = re.compile(
    r"<think>.*?</think>",
    flags=re.DOTALL,
)
_JSON_FENCE_PATTERN = re.compile(
    r"```(?:json)?\s*(.*?)\s*```",
    flags=re.DOTALL | re.IGNORECASE,
)


def clean_model_output(text: str) -> str:
    return _THINKING_TAG_PATTERN.sub("", text).strip()


def extract_json_text(text: str) -> str:
    cleaned = clean_model_output(text)
    fenced = _JSON_FENCE_PATTERN.search(cleaned)
    if fenced:
        return fenced.group(1).strip()

    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start != -1 and end != -1 and end > start:
        return cleaned[start : end + 1]

    return cleaned


def parse_packing_response(text: str) -> PackingResponse:
    try:
        payload = json.loads(extract_json_text(text))
    except json.JSONDecodeError as exc:
        raise ParseError(f"Invalid JSON: {exc.msg}") from exc

    try:
        return PackingResponse.model_validate(payload)
    except ValidationError as exc:
        raise ParseError(f"Schema validation failed: {exc}") from exc
