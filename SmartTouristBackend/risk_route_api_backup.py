"""Prototype hazard proximity screening of NSGA-II itinerary alternatives.

This is NOT road-network rerouting or verified hazard safety assessment.
"""
from contextlib import closing
from math import radians, sin, cos, asin, sqrt
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from hazard_api import connect, initialize_database
from nsga2_optimizer import optimize_itineraries

router = APIRouter(prefix='/api/itinerary', tags=['Risk-aware Itineraries'])

class RiskPreferences(BaseModel):
    budget: float = Field(gt=0)
    climate: str
    vibe: str
    available_hours: float = Field(gt=0)
    start_lat: float = Field(ge=-90, le=90)
    start_lon: float = Field(ge=-180, le=180)
    hazard_radius_km: float = Field(default=5, gt=0, le=50)
    include_test: bool = False

def distance_km(lat1, lon1, lat2, lon2):
    a, b, c, d = map(radians, (lat1, lon1, lat2, lon2))
    h = sin((c-a)/2)**2 + cos(a)*cos(c)*sin((d-b)/2)**2
    return 12742 * asin(min(1, sqrt(h)))

def active_hazards(include_test):
    initialize_database()
    query = "SELECT id, hazard_type, latitude, longitude, severity, description FROM hazard_reports WHERE status = 'active'"
    if not include_test:
        query += " AND UPPER(description) NOT LIKE '%TEST DATA%'"
    with closing(connect()) as connection:
        return [dict(r) for r in connection.execute(query).fetchall()]

@router.post('/risk-screen')
def risk_screen(prefs: RiskPreferences):
    # Import the dataset from the existing main module only at request time.
    from main import df
    try:
        optimized = optimize_itineraries(
            df=df, budget=prefs.budget, climate=prefs.climate, vibe=prefs.vibe,
            available_hours=prefs.available_hours, start_lat=prefs.start_lat,
            start_lon=prefs.start_lon
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    hazards = active_hazards(prefs.include_test)
    options = []
    for route in optimized['options']:
        nearby = []
        for hazard in hazards:
            matches = []
            for place in route['destinations']:
                distance = distance_km(hazard['latitude'], hazard['longitude'], place['lat'], place['lon'])
                if distance <= prefs.hazard_radius_km:
                    matches.append({'place_id': place['place_id'], 'place_name': place['place_name'], 'distance_km': round(distance, 2)})
            if matches:
                nearby.append({'hazard_id': hazard['id'], 'hazard_type': hazard['hazard_type'],
                               'severity': hazard['severity'], 'near_destinations': matches,
                               'verification_status': 'unverified'})
        options.append({**route, 'nearby_hazard_count': len(nearby), 'nearby_hazards': nearby,
                        'screening_status': 'REVIEW_REPORTED_HAZARDS' if nearby else 'NO_NEARBY_REPORTS_FOUND'})
    options.sort(key=lambda r: (r['nearby_hazard_count'], r['straight_line_km']))
    return {
        'status': 'success', 'mode': 'destination_proximity_screening',
        'radius_km': prefs.hazard_radius_km, 'active_reports_considered': len(hazards),
        'suggested_option': options[0] if options else None, 'screened_options': options,
        'warning': 'Unverified user reports and destination proximity only. Does not check road segments, establish safety, or guarantee hazard-free travel.'
    }
