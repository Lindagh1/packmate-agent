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
# Models sometimes emit \u escapes that are not valid 4-hex sequences.
_INVALID_UNICODE_ESCAPE = re.compile(r"\\u(?![0-9a-fA-F]{4})")
_TRAILING_COMMA = re.compile(r",(\s*[}\]])")
# Missing comma before the next object key on a following line.
_MISSING_COMMA_BEFORE_KEY = re.compile(
    r'("(?:\\.|[^"\\])*"|true|false|null|-?\d+(?:\.\d+)?)(\s*\n\s*")'
)
_MISSING_COMMA_AFTER_CONTAINER = re.compile(r'([}\]])(\s*")')


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


def sanitize_json_text(text: str) -> str:
    """Repair common model JSON defects that break json.loads."""
    repaired = _INVALID_UNICODE_ESCAPE.sub(r"\\\\u", text)
    repaired = _TRAILING_COMMA.sub(r"\1", repaired)
    repaired = _MISSING_COMMA_BEFORE_KEY.sub(r"\1,\2", repaired)
    repaired = _MISSING_COMMA_AFTER_CONTAINER.sub(r"\1,\2", repaired)
    return repaired


def parse_packing_response(text: str) -> PackingResponse:
    extracted = extract_json_text(text)
    try:
        payload = json.loads(extracted)
    except json.JSONDecodeError:
        try:
            payload = json.loads(sanitize_json_text(extracted))
        except json.JSONDecodeError as exc:
            raise ParseError(f"Invalid JSON: {exc.msg}") from exc

    if not isinstance(payload, dict):
        raise ParseError("Schema validation failed: expected a JSON object")

    try:
        return PackingResponse.model_validate(payload)
    except ValidationError as exc:
        raise ParseError(f"Schema validation failed: {exc}") from exc
