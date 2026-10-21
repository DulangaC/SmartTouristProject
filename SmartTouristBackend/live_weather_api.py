"""Open-Meteo live forecast and experimental forecast-assisted Random Forest screening.

The Random Forest was trained on completed-day weather observations. For a next-day
prediction made today, this module uses Open-Meteo's *forecast* of today's full-day
weather as a proxy. This is a distribution shift, not a validated live model.
"""
from datetime import date, datetime, timedelta
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
import requests
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/api/weather", tags=["Live Weather"])
LOCATIONS = {
    "kandy": (7.2906, 80.6337),
    "nuwara eliya": (6.9497, 80.7891),
    "ella": (6.8667, 81.0466),
    "sigiriya": (7.9570, 80.7603),
    "colombo": (6.9271, 79.8612),
}
MODEL_PATH = Path(__file__).resolve().parent / "hazard_ml" / "model_outputs" / "weather_risk_model_v2.joblib"
DAILY_KEYS = ["temperature_2m_max", "temperature_2m_min", "precipitation_sum", "rain_sum", "wind_speed_10m_max"]


def fetch_weather(location):
    key = location.strip().casefold()
    if key not in LOCATIONS:
        raise HTTPException(422, detail=f"Unknown location. Choose: {', '.join(LOCATIONS)}")
    lat, lon = LOCATIONS[key]
    params = {
        "latitude": lat, "longitude": lon,
        "current": "temperature_2m,precipitation,rain,wind_speed_10m",
        "daily": ",".join(DAILY_KEYS),
        "timezone": "Asia/Colombo", "forecast_days": 3,
    }
    try:
        response = requests.get("https://api.open-meteo.com/v1/forecast", params=params, timeout=20)
        response.raise_for_status()
        data = response.json()
    except (requests.RequestException, ValueError) as exc:
        raise HTTPException(502, detail=f"Weather provider unavailable: {exc}") from exc
    daily = data.get("daily") or {}
    dates = daily.get("time") or []
    if len(dates) < 2 or any(len(daily.get(k) or []) < 2 for k in DAILY_KEYS):
        raise HTTPException(502, detail="Weather provider returned incomplete daily data")
    forecasts = []
    for i, day in enumerate(dates):
        forecasts.append({
            "date": day,
            "temperature_max_c": daily["temperature_2m_max"][i],
            "temperature_min_c": daily["temperature_2m_min"][i],
            "precipitation_sum_mm": daily["precipitation_sum"][i],
            "rain_sum_mm": daily["rain_sum"][i],
            "wind_speed_max_kmh": daily["wind_speed_10m_max"][i],
        })
    return key, lat, lon, data.get("current") or {}, forecasts


@router.get("/locations")
def weather_locations():
    return {"locations": list(LOCATIONS)}


@router.get("/live")
def get_live_weather(location: str = "Kandy"):
    key, lat, lon, current, forecasts = fetch_weather(location)
    return {
        "status": "success", "source": "Open-Meteo forecast API",
        "location": key.title(), "latitude": lat, "longitude": lon,
        "timezone": "Asia/Colombo",
        "current": {
            "observed_at": current.get("time"),
            "temperature_c": current.get("temperature_2m"),
            "precipitation_mm": current.get("precipitation"),
            "rain_mm": current.get("rain"),
            "wind_speed_kmh": current.get("wind_speed_10m"),
        },
        "daily_forecasts": forecasts,
        "tomorrow_forecast": forecasts[1],
        "model_used": "Open-Meteo weather forecast; local Random Forest not used",
        "disclaimer": "Weather forecasts are not verified flood, landslide, or road-closure alerts.",
    }


@router.get("/forecast-assisted-ml")
def forecast_assisted_ml(location: str = "Kandy"):
    """Experimental screening for tomorrow using forecast *today* as model input."""
    key, lat, lon, _, forecasts = fetch_weather(location)
    if not MODEL_PATH.is_file():
        raise HTTPException(500, detail="Saved Random Forest model not found")
    today = forecasts[0]
    tomorrow = forecasts[1]
    if date.fromisoformat(tomorrow["date"]) != date.fromisoformat(today["date"]) + timedelta(days=1):
        raise HTTPException(502, detail="Provider forecast dates are not consecutive")
    values = {
        "latitude": lat, "longitude": lon,
        "temperature_2m_max": today["temperature_max_c"],
        "temperature_2m_min": today["temperature_min_c"],
        "precipitation_sum": today["precipitation_sum_mm"],
        "rain_sum": today["rain_sum_mm"],
        "wind_speed_10m_max": today["wind_speed_max_kmh"],
    }
    day = date.fromisoformat(today["date"])
    values.update({
        "month_sin": float(np.sin(2*np.pi*day.month/12)),
        "month_cos": float(np.cos(2*np.pi*day.month/12)),
        "day_of_year_sin": float(np.sin(2*np.pi*day.timetuple().tm_yday/365.25)),
        "day_of_year_cos": float(np.cos(2*np.pi*day.timetuple().tm_yday/365.25)),
    })
    if any(v is None or not np.isfinite(float(v)) for v in values.values()):
        raise HTTPException(502, detail="Weather provider returned missing model input data")
    try:
        # Load only the model created by your own trusted training script.
        bundle = joblib.load(MODEL_PATH)
        features = bundle["features"]
        inputs = pd.DataFrame([{name: values[name] for name in features}], columns=features)
        score = float(bundle["model"].predict_proba(inputs)[0, 1])
        threshold = float(bundle["probability_threshold"])
    except (KeyError, ValueError, TypeError) as exc:
        raise HTTPException(500, detail=f"Model feature mismatch: {exc}") from exc
    return {
        "status": "success", "mode": "experimental_forecast_assisted_ml",
        "location": key.title(), "latitude": lat, "longitude": lon,
        "input_date": today["date"], "predicted_date": tomorrow["date"],
        "prediction_target": "Next-day precipitation >= 20 mm",
        "random_forest_score": round(score, 4),
        "classification_threshold": threshold,
        "screening_result": "HIGHER RAINFALL CHANCE" if score >= threshold else "LOWER RAINFALL CHANCE",
        "open_meteo_tomorrow_precipitation_mm": tomorrow["precipitation_sum_mm"],
        "input_source": "Open-Meteo forecast for today's full-day conditions (not observed full-day measurements)",
        "warning": "Experimental only. Random Forest was trained on observed daily weather, not forecast inputs; this live-use approach is NOT validated. The score is not a calibrated probability or official hazard warning. Do not use for safety decisions.",
    }
