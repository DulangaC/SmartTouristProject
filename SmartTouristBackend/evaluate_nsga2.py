"""Evaluate the running Smart Tourist NSGA-II API; writes research-friendly CSV files.
Run from any folder with: python evaluate_nsga2.py
"""
import csv
import json
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

API = 'http://127.0.0.1:8000/api/itinerary/optimize'
CASES = [
    ('kandy_nature', 150, 'Moderate', 'Nature', 48, 7.2906, 80.6337),
    ('sigiriya_history', 100, 'Tropical', 'Historical', 24, 7.9570, 80.7603),
    ('kandy_culture', 120, 'Moderate', 'Culture', 24, 7.2906, 80.6337),
    ('low_budget', 20, 'Tropical', 'Adventure', 12, 7.9654, 80.7648),
]
OUT = Path(__file__).resolve().parent / 'evaluation_results'
OUT.mkdir(exist_ok=True)
summary = []
route_rows = []
for name, budget, climate, vibe, hours, lat, lon in CASES:
    payload = {'budget': budget, 'climate': climate, 'vibe': vibe,
               'available_hours': hours, 'start_lat': lat, 'start_lon': lon}
    req = Request(API, data=json.dumps(payload).encode(),
                  headers={'Content-Type': 'application/json'}, method='POST')
    started = time.perf_counter()
    try:
        with urlopen(req, timeout=120) as response:
            body = json.load(response)
        duration = round(time.perf_counter() - started, 3)
        options = body['result']['options']
        unique_routes = {tuple(d['place_id'] for d in r['destinations']) for r in options}
        all_valid = True
        for r in options:
            ids = [d['place_id'] for d in r['destinations']]
            checks = {
                'budget_ok': r['destination_cost_usd'] <= budget + 0.01,
                'time_ok': r['estimated_total_hours_proxy'] <= hours + 0.01,
                'count_ok': 2 <= len(ids) <= 6,
                'unique_stops_ok': len(ids) == len(set(ids)),
                'count_consistent': len(ids) == r['destination_count'],
            }
            passed = all(checks.values())
            all_valid &= passed
            route_rows.append({'scenario': name, 'option': r['option'],
                'stops': len(ids), 'cost_usd': r['destination_cost_usd'],
                'straight_line_km': r['straight_line_km'],
                'time_proxy_hours': r['estimated_total_hours_proxy'],
                'preference_match_percent': r['preference_match_percent'],
                'sightseeing_value': r['sightseeing_value'],
                'passed_constraints': passed,
                'destination_ids': '-'.join(map(str, ids))})
        summary.append({'scenario': name, 'status': 'PASS' if all_valid else 'FAIL',
                        'runtime_seconds': duration, 'returned_options': len(options),
                        'distinct_displayed_routes': len(unique_routes),
                        'candidate_pareto_routes_reported': body['result']['pareto_routes_found'],
                        'error': ''})
        print(f'{name}: {summary[-1]["status"]}, {duration}s, {len(unique_routes)} distinct routes')
    except (HTTPError, URLError, KeyError, ValueError, TimeoutError) as exc:
        summary.append({'scenario': name, 'status': 'ERROR', 'runtime_seconds': '',
                        'returned_options': 0, 'distinct_displayed_routes': 0,
                        'candidate_pareto_routes_reported': '', 'error': str(exc)})
        print(f'{name}: ERROR: {exc}')

for filename, rows in [('summary.csv', summary), ('routes.csv', route_rows)]:
    if rows:
        with (OUT / filename).open('w', newline='', encoding='utf-8-sig') as f:
            writer = csv.DictWriter(f, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
print(f'\nSaved evaluation CSV files in: {OUT}')
