from fastapi import FastAPI, HTTPException, Query

from app.models.weather import WeatherResponse
from app.tools.weather import CityNotFoundError, WeatherToolError, get_weather

app = FastAPI(title="Packmate API", version="0.1.0")


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
