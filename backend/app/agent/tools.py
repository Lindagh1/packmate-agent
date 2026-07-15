import json

from app.tools.weather import CityNotFoundError, WeatherToolError, get_weather

TOOL_DEFINITIONS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Fetch up to 14 days of weather forecast for a city.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "City name"},
                    "days": {
                        "type": "integer",
                        "description": "Number of forecast days (1-14, default 14)",
                    },
                },
                "required": ["city"],
            },
        },
    }
]


async def execute_tool(name: str, arguments: str) -> str:
    args = json.loads(arguments)

    if name != "get_weather":
        return json.dumps({"error": f"Unknown tool: {name}"})

    try:
        result = await get_weather(args["city"], args.get("days", 14))
        return json.dumps(result.model_dump())
    except CityNotFoundError as exc:
        return json.dumps({"error": str(exc)})
    except WeatherToolError as exc:
        return json.dumps({"error": str(exc)})
