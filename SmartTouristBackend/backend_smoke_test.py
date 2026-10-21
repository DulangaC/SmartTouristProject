"""Non-destructive local API smoke tests for Smart Tourist backend.
Run while Uvicorn is running: python backend_smoke_test.py
Does not create, modify, or resolve hazard reports.
"""
import json
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

BASE = 'http://127.0.0.1:8000'
ROOT = Path(__file__).resolve().parent

checks = [
    ('Home', 'GET', '/', None),
    ('Destinations', 'GET', '/api/destinations', None),
    ('Preferences', 'GET', '/api/preferences/options', None),
    ('Hazard reports', 'GET', '/api/hazards', None),
    ('Hazard GeoJSON', 'GET', '/api/hazards/geojson', None),
    ('Weather locations', 'GET', '/api/weather/locations', None),
    ('Historical Random Forest', 'GET', '/api/weather/historical-prediction?location=Kandy&date=2025-10-01', None),
    ('Live weather', 'GET', '/api/weather/live?location=Kandy', None),
    ('Forecast-assisted ML', 'GET', '/api/weather/forecast-assisted-ml?location=Kandy', None),
    ('NSGA-II', 'POST', '/api/itinerary/optimize', {'budget': 150, 'climate': 'Moderate', 'vibe': 'Nature', 'available_hours': 48, 'start_lat': 7.2906, 'start_lon': 80.6337}),
    ('Risk screening', 'POST', '/api/itinerary/risk-screen', {'budget': 150, 'climate': 'Moderate', 'vibe': 'Nature', 'available_hours': 48, 'start_lat': 7.2906, 'start_lon': 80.6337, 'hazard_radius_km': 5, 'include_test': False}),
]

print('LOCAL FILE CHECKS')
for path in ['sri_lanka_destinations.csv', 'hazard_ml/historical_weather.csv', 'hazard_ml/model_outputs/weather_risk_model_v2.joblib', 'hazard_ml/hazard_reports.db']:
    print(('FOUND  ' if (ROOT / path).exists() else 'MISSING'), path)

print('\nAPI SMOKE TESTS (no database modifications)')
results = []
for name, method, path, payload in checks:
    try:
        data = None if payload is None else json.dumps(payload).encode('utf-8')
        req = Request(BASE + path, data=data, method=method, headers={'Content-Type': 'application/json'})
        with urlopen(req, timeout=75) as response:
            body = json.load(response)
            code = response.status
        valid = isinstance(body, dict)
        if name == 'Hazard GeoJSON':
            valid = valid and body.get('type') == 'FeatureCollection'
        if name in ('NSGA-II', 'Risk screening'):
            valid = valid and body.get('status') == 'success'
        outcome = 'PASS' if code == 200 and valid else 'CHECK'
        details = f'HTTP {code}'
    except HTTPError as e:
        outcome, details = 'FAIL', f'HTTP {e.code}: {e.read(250).decode("utf-8", errors="replace")}'
    except (URLError, TimeoutError, ValueError, OSError) as e:
        outcome, details = 'FAIL', str(e)
    results.append((name, outcome, details))
    print(f'{outcome:5} {name:25} {details}')

print(f'\nRESULT: {sum(r[1] == "PASS" for r in results)}/{len(results)} endpoints passed')
print('NOTE: This tests connectivity and response structure, not correctness, safety, or authorization.')
