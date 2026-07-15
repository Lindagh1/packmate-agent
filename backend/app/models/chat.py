from datetime import date

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.profile import TravelerProfile


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    traveler_profile: TravelerProfile | None = None


class PackingItem(BaseModel):
    name: str
    category: str
    quantity: int = Field(..., ge=1)
    reason: str
    essential: bool


class WeatherSummary(BaseModel):
    location: str
    overview: str
    min_temperature: str | None = None
    max_temperature: str | None = None
    conditions: str | None = None


class PackingResponse(BaseModel):
    destination: str
    start_date: date
    end_date: date
    weather_summary: WeatherSummary
    packing_items: list[PackingItem] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    baggage_warnings: list[str] = Field(default_factory=list)
    profile_considerations: list[str] = Field(default_factory=list)
    rules_disclaimer: str
    language: str

    @field_validator("start_date", "end_date", mode="before")
    @classmethod
    def parse_iso_date(cls, value: object) -> object:
        if isinstance(value, date):
            return value
        if isinstance(value, str):
            return date.fromisoformat(value)
        return value

    @model_validator(mode="after")
    def validate_date_order(self) -> "PackingResponse":
        if self.end_date < self.start_date:
            raise ValueError("end_date cannot be earlier than start_date")
        return self
