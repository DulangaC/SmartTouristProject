"""Prototype screening of straight-line itinerary legs against unverified hazard reports.
This is NOT road geometry, road closure detection, or safety-grade rerouting.
"""
from contextlib import closing
from math import radians, sin, cos, asin, sqrt, atan2
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
    must_visit_places: list[str] = Field(default_factory=list)
    selected_route: dict | None = None
    hazard_radius_km: float = Field(default=5, gt=0, le=50)
    include_test: bool = False

def distance_km(lat1, lon1, lat2, lon2):
    a, b, c, d = map(radians, (lat1, lon1, lat2, lon2))
    h = sin((c-a)/2)**2 + cos(a)*cos(c)*sin((d-b)/2)**2
    return 12742 * asin(min(1, sqrt(h)))

def point_to_leg_km(hazard, start, end):
    """Approximate point-to-straight-segment distance on a local equirectangular plane."""
    lat0 = radians((float(start['lat']) + float(end['lat']) + float(hazard['latitude'])) / 3)
    def xy(lat, lon):
        return (111.195 * float(lon) * cos(lat0), 111.195 * float(lat))
    ax, ay = xy(start['lat'], start['lon'])
    bx, by = xy(end['lat'], end['lon'])
    px, py = xy(hazard['latitude'], hazard['longitude'])
    dx, dy = bx - ax, by - ay
    t = max(0., min(1., ((px-ax)*dx+(py-ay)*dy)/(dx*dx+dy*dy))) if dx*dx+dy*dy > 0 else 0.
    return sqrt((px-ax-t*dx)**2 + (py-ay-t*dy)**2)

def active_hazards(include_test):
    initialize_database()
    sql = "SELECT id, hazard_type, latitude, longitude, severity, description FROM hazard_reports WHERE status='active'"
    if not include_test:
        sql += " AND UPPER(description) NOT LIKE '%TEST DATA%'"
    with closing(connect()) as conn:
        return [dict(r) for r in conn.execute(sql).fetchall()]

def annotate(route, hazards, radius, origin):
    stops = route['destinations']
    points = [origin, *stops]
    nearby = []
    for hazard in hazards:
        matches = []
        for place in stops:
            dist = distance_km(hazard['latitude'], hazard['longitude'], place['lat'], place['lon'])
            if dist <= radius:
                matches.append({'place_id': place['place_id'], 'place_name': place['place_name'], 'distance_km': round(dist, 2)})
        leg_matches = []
        for i, (a,b) in enumerate(zip(points, points[1:])):
            dist = point_to_leg_km(hazard, a, b)
            if dist <= radius:
                leg_matches.append({'leg_number': i+1, 'distance_km': round(dist,2)})
        if matches or leg_matches:
            nearby.append({'hazard_id': hazard['id'], 'hazard_type': hazard['hazard_type'],
                           'severity': hazard['severity'], 'near_destinations': matches,
                           'near_straight_line_legs': leg_matches, 'verification_status': 'unverified'})
    return {**route, 'nearby_hazard_count': len(nearby), 'nearby_hazards': nearby,
            'screening_status': 'REVIEW_REPORTED_HAZARDS' if nearby else 'NO_NEARBY_REPORTS_FOUND'}

def route_signature(route):
    return tuple(int(p['place_id']) for p in route['destinations'])

@router.post('/risk-screen')
def risk_screen(prefs: RiskPreferences):
    from main import df
    kwargs = dict(budget=prefs.budget, climate=prefs.climate, vibe=prefs.vibe,
                  available_hours=prefs.available_hours, start_lat=prefs.start_lat,
                  start_lon=prefs.start_lon, must_visit_places=prefs.must_visit_places)
    try:
        optimized = optimize_itineraries(df=df, **kwargs)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    origin = {'lat': prefs.start_lat, 'lon': prefs.start_lon}
    hazards = active_hazards(prefs.include_test)
    options = [annotate(route, hazards, prefs.hazard_radius_km, origin) for route in optimized['options']]
    selected = None
    if prefs.selected_route is not None:
        raw = prefs.selected_route
        stops = raw.get('destinations') if isinstance(raw, dict) else None
        if not isinstance(stops, list) or not 2 <= len(stops) <= 6:
            raise HTTPException(status_code=422, detail='Selected itinerary must have 2 to 6 destinations.')
        valid = {int(p['place_id']): p for p in df.to_dict('records')}
        try:
            ids = [int(p['place_id']) for p in stops]
            if len(ids) != len(set(ids)) or any(i not in valid for i in ids):
                raise ValueError()
            # Reconstruct coordinates from trusted dataset, never trust client-supplied coordinates.
            checked_stops = [{'place_id': i, 'place_name': str(valid[i]['place_name']),
                              'lat': float(valid[i]['lat']), 'lon': float(valid[i]['lon'])} for i in ids]
        except (ValueError, TypeError, KeyError):
            raise HTTPException(status_code=422, detail='Selected itinerary contains invalid destination IDs.')
        selected = annotate({**raw, 'destinations': checked_stops}, hazards, prefs.hazard_radius_km, origin)
    target = selected or options[0]
    alternatives = [r for r in options if route_signature(r) != route_signature(target)]
    alternatives.sort(key=lambda r: (r['nearby_hazard_count'], r['straight_line_km']))
    suggested = alternatives[0] if alternatives and target['nearby_hazard_count'] else None
    generated = False
    note = None
    if target['nearby_hazard_count'] and (suggested is None or suggested['nearby_hazard_count']):
        # Exclude destinations near reports, and check resulting straight-line legs too.
        def outside_reports(place):
            return all(distance_km(place['lat'], place['lon'], h['latitude'], h['longitude']) > prefs.hazard_radius_km for h in hazards)
        filtered = df[df.apply(outside_reports, axis=1)].copy()
        if len(filtered) >= 2:
            try:
                generated_options = optimize_itineraries(df=filtered, **kwargs)['options']
                screened = [annotate(r, hazards, prefs.hazard_radius_km, origin) for r in generated_options]
                screened = [r for r in screened if route_signature(r) != route_signature(target)]
                screened.sort(key=lambda r: (r['nearby_hazard_count'], r['straight_line_km']))
                if screened and (suggested is None or screened[0]['nearby_hazard_count'] < suggested['nearby_hazard_count']):
                    suggested = {**screened[0], 'option': 'hazard_avoidance_candidate'}
                    generated = True
            except ValueError:
                pass
        if suggested is None:
            note = 'No alternative candidate could be generated under the selected constraints.'
    if suggested is not None and suggested['nearby_hazard_count'] > 0:
        note = 'Alternative also has nearby reports; it must not be described as safe.'
    elif suggested is not None:
        note = 'Alternative has fewer nearby reports along approximate straight-line legs; actual roads were not checked.'
    return {'status':'success', 'mode':'straight_line_leg_and_destination_proximity',
            'radius_km':prefs.hazard_radius_km, 'active_reports_considered':len(hazards),
            'selected_route':selected, 'selected_route_has_reports': bool(target['nearby_hazard_count']),
            'suggested_option':suggested, 'alternative_generated':generated,
            'alternative_note':note, 'screened_options':options,
            'recommendation_status': 'REVIEW_REPORTED_HAZARDS' if target['nearby_hazard_count'] else 'NO_NEARBY_REPORTS_FOUND',
            'warning':'Reports are unverified. Proximity to straight-line itinerary segments is not proximity to actual roads. No report does not mean safe travel.'}
