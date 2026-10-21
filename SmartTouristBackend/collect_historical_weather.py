"""Download historical DAILY weather observations for selected Sri Lankan locations.

This is weather feature data, NOT labelled flood/landslide/roadblock events.
Run: python collect_historical_weather.py
"""
from pathlib import Path
import requests
import pandas as pd

LOCATIONS = {
    "Kandy": (7.2906, 80.6337),
    "Nuwara Eliya": (6.9497, 80.7891),
    "Ella": (6.8667, 81.0466),
    "Sigiriya": (7.9570, 80.7603),
    "Colombo": (6.9271, 79.8612),
}
START_DATE = "2023-01-01"
END_DATE = "2025-12-31"
OUTPUT = Path(__file__).resolve().parent / "hazard_ml" / "historical_weather.csv"
API_URL = "https://archive-api.open-meteo.com/v1/archive"
DAILY_FIELDS = [
    "temperature_2m_max",
    "temperature_2m_min",
    "precipitation_sum",
    "rain_sum",
    "wind_speed_10m_max",
]


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    frames = []
    for name, (latitude, longitude) in LOCATIONS.items():
        print(f"Downloading: {name} ...", flush=True)
        params = {
            "latitude": latitude,
            "longitude": longitude,
            "start_date": START_DATE,
            "end_date": END_DATE,
            "daily": ",".join(DAILY_FIELDS),
            "timezone": "Asia/Colombo",
        }
        response = requests.get(API_URL, params=params, timeout=90)
        response.raise_for_status()
        payload = response.json()
        if "daily" not in payload or "time" not in payload["daily"]:
            raise ValueError(f"No daily data for {name}: {payload}")
        daily = pd.DataFrame(payload["daily"])
        daily = daily.rename(columns={"time": "date"})
        daily.insert(0, "location", name)
        daily.insert(1, "latitude", latitude)
        daily.insert(2, "longitude", longitude)
        frames.append(daily)
        print(f"  {len(daily)} days received")

    data = pd.concat(frames, ignore_index=True)
    data.to_csv(OUTPUT, index=False)
    print(f"\nSUCCESS: saved {len(data)} rows to {OUTPUT}")
    print("Columns:", ", ".join(data.columns))
    print("IMPORTANT: These are weather measurements, not verified hazard labels.")
    print("Do not train or report a flood/landslide Random Forest from this file alone.")


if __name__ == "__main__":
    try:
        main()
    except (requests.RequestException, ValueError) as exc:
        print(f"ERROR: {exc}")
        raise SystemExit(1)
