import json
import re
import datetime
import requests
from openai import OpenAI
from dotenv import load_dotenv
import os

# Charge les variables du fichier .env (si on est en local)
load_dotenv()                 

# ─── CONFIGURATION ──────────────────────────────────────────────
BASE_URL = "https://litellm-prod.apps.maas.redhatworkshops.io/v1"
MODEL    = "llama-scout-17b"
API_KEY  = os.getenv("LITELLM_API_KEY")
# ───────────────────────────────────────────────────────────────

client = OpenAI(base_url=BASE_URL, api_key=API_KEY)

def get_today() -> str:
    return datetime.date.today().strftime("%A %Y-%m-%d")

def build_system_prompt() -> str:
    return f"""You are PackMate, an expert travel assistant. 
Today is {get_today()}.

RULES:
1. LANGUAGE: Always reply in the user's language (French if they speak French).
2. DATES & TIME: 
   - "Ce week-end" = The upcoming Saturday and Sunday.
   - "Week-end prochain" = The Saturday and Sunday of the FOLLOWING week.
   - "Semaine prochaine" = The next full week.
3. TOOL USE: You MUST call 'get_weather' ONCE per destination. When the trip is in the future (like next weekend), set 'days' to 14 to get a long forecast, then ONLY look at the specific travel dates in the JSON to answer.
4. TEMPERATURES: You MUST explicitly state the absolute MINIMUM and absolute MAXIMUM temperatures of the specific travel dates, and mention the exact dates they occur.
5. PACKING: Provide a structured packing list (Clothing, Shoes, Tech, etc.) perfectly adapted to these temperatures and conditions.
"""

WMO_CODES = {
    0: "Dégagé ☀️", 1: "Peu nuageux 🌤", 2: "Partiellement nuageux ⛅", 3: "Couvert ☁️",
    45: "Brouillard 🌫", 51: "Bruine 🌦", 61: "Pluie légère 🌧", 63: "Pluie 🌧",
    71: "Neige 🌨", 95: "Orage ⛈",
}

def get_weather(city: str, days: int = 14) -> dict:
    # 🛡️ CORRECTION DU BUG : On force la conversion en entier. Si l'IA envoie n'importe quoi, on force à 14 jours.
    try:
        days_int = int(days)
    except (ValueError, TypeError):
        days_int = 14
        
    # On s'assure que le nombre de jours est compris entre 1 et 14 (limite de l'API gratuite)
    days_int = min(max(days_int, 1), 14)

    geo = requests.get(
        "https://geocoding-api.open-meteo.com/v1/search",
        params={"name": city, "count": 1, "language": "fr"}, timeout=10
    ).json()
    
    if not geo.get("results"):
        return {"error": f"Ville '{city}' introuvable"}
    
    loc = geo["results"][0]
    w = requests.get(
        "https://api.open-meteo.com/v1/forecast",
        params={
            "latitude": loc["latitude"], "longitude": loc["longitude"],
            "daily": "temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum",
            "timezone": "auto", 
            "forecast_days": days_int
        }, timeout=10
    ).json()

    daily = w["daily"]
    forecasts = []
    
    for i in range(len(daily["time"])):
        forecasts.append({
            "date": daily["time"][i],
            "min_temp": f"{daily['temperature_2m_min'][i]}°C",
            "max_temp": f"{daily['temperature_2m_max'][i]}°C",
            "pluie_mm": daily["precipitation_sum"][i],
            "condition": WMO_CODES.get(daily["weathercode"][i], "Variable")
        })

    return {
        "destination": f"{loc['name']}, {loc.get('country', '')}",
        "forecast": forecasts
    }

TOOLS = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Récupère les prévisions météo pour une ville. Mets 'days' à 14 pour couvrir les week-ends ou semaines à venir.",
        "parameters": {
            "type": "object",
            "properties": {
                "city": {"type": "string", "description": "Nom de la ville"},
                "days": {"type": "integer", "description": "Nombre de jours à récupérer à partir d'aujourd'hui (ex: 14)"}
            },
            "required": ["city", "days"],
        },
    },
}]

def clean(text: str) -> str:
    if not text:
        return ""
    return re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()

def chat_turn(messages: list) -> str:
    # On donne 3 essais maximum à l'agent pour lire l'outil et répondre
    for _ in range(3):
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            tools=TOOLS,
            tool_choice="auto"
        )
        msg = response.choices[0].message
        
        # Si le LLM veut appeler la météo
        if msg.tool_calls:
            messages.append(msg)
            for tc in msg.tool_calls:
                args = json.loads(tc.function.arguments)
                # On passe les arguments récupérés (s'il n'y a pas de jours, on met 14 par défaut)
                result = get_weather(args.get("city"), args.get("days", 14))
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.id,
                    "content": json.dumps(result, ensure_ascii=False)
                })
            continue 
        
        # Si le LLM a formulé sa réponse finale
        if msg.content:
            final_content = clean(msg.content)
            messages.append({"role": "assistant", "content": final_content})
            return final_content
            
    return "Désolé, une erreur inattendue est survenue."

def get_system_prompt() -> dict:
    return {"role": "system", "content": build_system_prompt()}