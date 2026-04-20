import json
import re
import datetime
import requests
import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()                 

# --- CLUSTER / MAAS CONFIG ---
BASE_URL = os.getenv("BASE_URL")
MODEL    = os.getenv("MODEL")
API_KEY  = os.getenv("LITELLM_API_KEY")

client = OpenAI(base_url=BASE_URL, api_key=API_KEY)

def get_today() -> str:
    return datetime.date.today().strftime("%A %Y-%m-%d")

def build_system_prompt() -> str:
    return f"""You are PackMate, a professional AI travel assistant. Today is {get_today()}.

YOUR MISSION:
When a user mentions a destination and a date (like "tomorrow" or "next weekend"), you must:
1. CALL the 'get_weather' tool to get the facts.
2. ANALYZE the temperatures and weather conditions for the SPECIFIC dates.
3. ADVISE the user by creating a tailored packing list.

STRICT OUTPUT RULES:
- LANGUAGE: Always reply in the user's language (French if they speak French).
- TONE: Professional and concise.
- STRUCTURE: 
    * Start with a brief weather summary for the destination.
    * Use a Markdown Table for the temperatures (Date | Min | Max | Condition).
    * Provide a categorized Packing List (Clothes, Shoes, Essentials) using bullet points.
- REASONING: If it's cold (<10°C), suggest warm layers. If it rains, suggest an umbrella.
"""

WMO_CODES = {
    0: "Clear Sky ☀️", 1: "Mainly Clear 🌤", 2: "Partly Cloudy ⛅", 3: "Overcast ☁️",
    45: "Fog 🌫", 51: "Drizzle 🌦", 61: "Slight Rain 🌧", 63: "Rain 🌧",
    71: "Snow 🌨", 95: "Thunderstorm ⛈",
}

def get_weather(city: str, days: int = 14) -> dict:
    """Real-time tool to fetch weather and geocoding."""
    try:
        days_int = min(max(int(days), 1), 14)
        # 1. Geocoding
        geo = requests.get("https://geocoding-api.open-meteo.com/v1/search",
                           params={"name": city, "count": 1}, timeout=10).json()
        if not geo.get("results"): return {"error": f"City '{city}' not found."}
        
        loc = geo["results"][0]
        # 2. Forecast
        w = requests.get("https://api.open-meteo.com/v1/forecast",
                         params={
                             "latitude": loc["latitude"], "longitude": loc["longitude"],
                             "daily": "temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum",
                             "timezone": "auto", "forecast_days": days_int
                         }, timeout=10).json()
        
        daily = w["daily"]
        forecasts = []
        for i in range(len(daily["time"])):
            forecasts.append({
                "date": daily["time"][i],
                "min": f"{daily['temperature_2m_min'][i]}°C",
                "max": f"{daily['temperature_2m_max'][i]}°C",
                "condition": WMO_CODES.get(daily["weathercode"][i], "Variable")
            })
        return {"location": loc['name'], "forecast": forecasts}
    except Exception as e:
        return {"error": f"Tool error: {str(e)}"}

TOOLS = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Fetch 14-day weather forecast for a city. Use this to prepare packing lists.",
        "parameters": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "City name"},
                "days": {"type": "integer", "description": "Number of days (default 14)"}
            },
            "required": ["city"],
        },
    },
}]

def chat_turn(messages: list) -> str:
    """The Agentic Loop (ReAct)"""
    for i in range(3):
        response = client.chat.completions.create(
            model=MODEL, messages=messages, tools=TOOLS, tool_choice="auto"
        )
        msg = response.choices[0].message
        
        if msg.tool_calls:
            messages.append(msg)
            for tc in msg.tool_calls:
                args = json.loads(tc.function.arguments)
                # Logging for Debug in OpenShift Terminal
                print(f">>> [AGENT] Thinking... calling weather for: {args.get('city')}")
                result = get_weather(args.get("city"), args.get("days", 14))
                messages.append({"role": "tool", "tool_call_id": tc.id, "content": json.dumps(result)})
            continue 
        
        if msg.content:
            # Clean LLM internal 'thinking' tags if present
            final_txt = re.sub(r"<think>.*?</think>", "", msg.content, flags=re.DOTALL).strip()
            messages.append({"role": "assistant", "content": final_txt})
            return final_txt
            
    return "I am sorry, I couldn't process your request. Please try again."

def get_system_prompt() -> dict:
    return {"role": "system", "content": build_system_prompt()}
