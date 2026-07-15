from typing import Literal

from pydantic import BaseModel, Field


class TravelerProfile(BaseModel):
    trip_type: Literal["leisure", "business"]
    baggage_type: Literal["cabin", "checked", "both"]
    activities: list[str] = Field(default_factory=list)
    clothing_preferences: list[str] = Field(default_factory=list)
    medical_or_accessibility_notes: list[str] | None = None
    available_items: list[str] | None = None

    def for_agent(self) -> dict:
        """Full profile payload for the LLM tool (may include medical notes)."""
        return self.model_dump()

    def for_logging(self) -> dict:
        """Safe profile payload without sensitive medical notes."""
        data = self.model_dump()
        has_medical = bool(self.medical_or_accessibility_notes)
        data.pop("medical_or_accessibility_notes", None)
        data["has_medical_or_accessibility_notes"] = has_medical
        return data
