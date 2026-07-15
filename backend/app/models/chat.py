from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)


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
    start_date: str
    end_date: str
    weather_summary: WeatherSummary
    packing_items: list[PackingItem] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    language: str
