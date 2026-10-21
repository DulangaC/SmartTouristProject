from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from pathlib import Path
import pandas as pd

from nsga2_optimizer import optimize_itineraries
from weather_prediction_api import router as weather_router
from live_weather_api import router as live_weather_router
from hazard_api import router as hazard_router
from hazard_map_api import router as hazard_map_router
from risk_route_api import router as risk_route_router


app = FastAPI(title="Smart Tourist Routing and Risk Alert System", version="0.4.0")

# Allow the Flutter web app running on localhost to call the API during development.
# Restrict origins appropriately before public deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):[0-9]+",
    allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
    allow_headers=["Content-Type", "Accept", "X-Admin-Key"],
)

BASE_DIR = Path(__file__).resolve().parent
DATASET_PATH = BASE_DIR / "sri_lanka_destinations.csv"
df = pd.read_csv(DATASET_PATH)

app.include_router(weather_router)
app.include_router(live_weather_router)
app.include_router(hazard_router)
app.include_router(hazard_map_router)
app.include_router(risk_route_router)


class TouristPreferences(BaseModel):
    budget: float = Field(gt=0)
    climate: str
    vibe: str
    available_hours: float = Field(gt=0)


class OptimizationPreferences(TouristPreferences):
    start_lat: float = Field(ge=-90, le=90)
    start_lon: float = Field(ge=-180, le=180)
    must_visit_places: list[str] = Field(default_factory=list)


@app.get("/")
def home():
    return {"message": "Smart Tourist Backend is running", "status": "success"}


@app.get("/api/destinations")
def get_destinations():
    return {"total": len(df), "destinations": df.to_dict(orient="records")}


@app.get("/api/preferences/options")
def get_preference_options():
    return {
        "climates": sorted(df["climate"].dropna().unique().tolist()),
        "vibes": sorted(df["vibe"].dropna().unique().tolist()),
    }


@app.post("/api/itinerary/recommend")
def recommend_destinations(preferences: TouristPreferences):
    filtered = df[
        (df["climate"].str.lower() == preferences.climate.strip().lower()) &
        (df["vibe"].str.lower() == preferences.vibe.strip().lower())
    ].sort_values("avg_cost_usd")
    selected = []
    total_cost = 0.0
    total_hours = 0.0
    for _, place in filtered.iterrows():
        cost = float(place["avg_cost_usd"])
        hours = float(place["visit_hours"])
        if total_cost + cost <= preferences.budget and total_hours + hours <= preferences.available_hours:
            selected.append({
                "place_id": int(place["place_id"]),
                "place_name": str(place["place_name"]),
                "climate": str(place["climate"]),
                "vibe": str(place["vibe"]),
                "cost_usd": cost,
                "visit_hours": hours,
                "lat": float(place["lat"]),
                "lon": float(place["lon"]),
            })
            total_cost += cost
            total_hours += hours
    if not selected:
        raise HTTPException(status_code=404, detail="No destinations match the selected preferences and limits")
    return {
        "status": "success", "algorithm": "Basic filtering (not NSGA-II)",
        "total_destinations": len(selected),
        "total_cost_usd": round(total_cost, 2),
        "total_visit_hours": round(total_hours, 2),
        "recommended_destinations": selected,
    }


@app.post("/api/itinerary/optimize")
def optimize_route(preferences: OptimizationPreferences):
    try:
        result = optimize_itineraries(
            df=df, budget=preferences.budget, climate=preferences.climate,
            vibe=preferences.vibe, available_hours=preferences.available_hours,
            start_lat=preferences.start_lat, start_lon=preferences.start_lon,
            must_visit_places=preferences.must_visit_places,
        )
        return {"status": "success", "result": result}
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
