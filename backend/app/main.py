from fastapi import FastAPI, HTTPException, Query

from app.agent.exceptions import AgentResponseError, LLMConfigurationError
from app.agent.service import AgentService
from app.models.chat import ChatRequest, PackingResponse
from app.models.weather import WeatherResponse
from app.tools.weather import CityNotFoundError, WeatherToolError, get_weather

app = FastAPI(title="Packmate API", version="0.2.0")
agent_service = AgentService()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/v1/weather", response_model=WeatherResponse)
async def weather(
    city: str = Query(..., min_length=1),
    days: int = Query(default=14, ge=1, le=14),
) -> WeatherResponse:
    try:
        return await get_weather(city, days)
    except CityNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except WeatherToolError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.post("/api/v1/chat", response_model=PackingResponse)
async def chat(request: ChatRequest) -> PackingResponse:
    try:
        return await agent_service.chat(request.message, request.traveler_profile)
    except LLMConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except AgentResponseError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
