"""Sanitized progress stages for chat streaming (never include user content)."""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Literal

ProgressStage = Literal[
    "preparing",
    "weather",
    "baggage_rules",
    "generating",
]

ProgressCallback = Callable[[ProgressStage], Awaitable[None]]
