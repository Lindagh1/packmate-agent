from fastapi import FastAPI, HTTPException, Query, Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

from app.agent.exceptions import AgentResponseError, LLMConfigurationError
from app.agent.service import AgentService
from app.models.chat import ChatRequest, PackingResponse
from app.models.weather import WeatherResponse
from app.observability import (
    HTTP_DURATION,
    HTTP_REQUESTS,
    PACKMATE_VERSION,
    Timer,
    metrics_payload,
    setup_telemetry,
)
from app.tools.weather import CityNotFoundError, WeatherToolError, get_weather

app = FastAPI(title="Packmate API", version=PACKMATE_VERSION)
agent_service = AgentService()
setup_telemetry(app)


class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):  # type: ignore[no-untyped-def]
        timer = Timer()
        response = await call_next(request)
        endpoint = request.url.path
        if endpoint not in {"/metrics"}:
            HTTP_REQUESTS.labels(
                method=request.method,
                endpoint=endpoint,
                status=str(response.status_code),
            ).inc()
            HTTP_DURATION.labels(method=request.method, endpoint=endpoint).observe(
                timer.seconds()
            )
        return response


app.add_middleware(MetricsMiddleware)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready")
def ready() -> dict[str, str]:
    """Readiness: app can accept requests (does not require external LLM)."""
    return {"status": "ready", "version": PACKMATE_VERSION}


@app.get("/metrics")
def metrics() -> Response:
    payload, content_type = metrics_payload()
    return Response(content=payload, media_type=content_type)


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
