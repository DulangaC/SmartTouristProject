"""NSGA-II itinerary research prototype.
Straight-line distances and 40 km/h proxy are NOT real road routes/travel times.
Budget covers destination fees only. Do not use as safety-critical navigation.
"""
from math import radians, sin, cos, asin, sqrt
import numpy as np
from pymoo.core.problem import ElementwiseProblem
from pymoo.algorithms.moo.nsga2 import NSGA2
from pymoo.optimize import minimize


def km_between(a, b):
    lat1, lon1 = radians(float(a['lat'])), radians(float(a['lon']))
    lat2, lon2 = radians(float(b['lat'])), radians(float(b['lon']))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
    return 12742 * asin(min(1, sqrt(h)))


def optimize_itineraries(df, budget, climate, vibe, available_hours, start_lat, start_lon, must_visit_places=None):
    if budget <= 0 or available_hours <= 0:
        raise ValueError('Budget and available hours must be positive.')
    required = {'place_id','place_name','climate','vibe','avg_cost_usd','visit_hours','lat','lon'}
    if not required.issubset(df.columns):
        raise ValueError('Destination CSV is missing required columns.')
    places = df.dropna(subset=list(required)).to_dict('records')
    if len(places) < 2:
        raise ValueError('At least two destinations are required.')
    for p in places:
        p['score'] = (int(str(p['climate']).casefold() == climate.strip().casefold()) +
                      int(str(p['vibe']).casefold() == vibe.strip().casefold()))
    must_visit_places = must_visit_places or []
    requested = [str(name).strip() for name in must_visit_places if str(name).strip()]
    if len(requested) > 6:
        raise ValueError('Select no more than six must-visit destinations.')
    lookup = {str(p['place_name']).strip().casefold(): p for p in places}
    missing = [name for name in requested if name.casefold() not in lookup]
    if missing:
        raise ValueError('Unknown destinations: ' + ', '.join(missing) + '. Select destinations from the available list.')
    mandatory_ids = {int(lookup[name.casefold()]['place_id']) for name in requested}
    # All records are candidates. Use a bounded search for an interactive prototype.
    places.sort(key=lambda p: (int(p['place_id']) not in mandatory_ids, -p['score'], float(p['avg_cost_usd']), int(p['place_id'])))
    places = places[:100]
    n = len(places)
    origin = {'lat': start_lat, 'lon': start_lon}
    max_stops = min(6, n)
    mandatory = [p for p in places if int(p['place_id']) in mandatory_ids]
    mandatory_indices = {i for i,p in enumerate(places) if int(p['place_id']) in mandatory_ids}

    def decode(x):
        # Last variable controls number of stops (2..6); other keys encode order.
        count = max(len(mandatory_indices), min(max_stops, 2 + int(min(float(x[-1]), 0.999999) * (max_stops - 1))))
        indices = [int(i) for i in np.argsort(x[:-1]) if int(i) in mandatory_indices]
        indices += [int(i) for i in np.argsort(x[:-1]) if int(i) not in mandatory_indices][:count - len(indices)]
        return [places[int(i)] for i in indices]

    def evaluate(chosen):
        cost = sum(float(p['avg_cost_usd']) for p in chosen)
        visit = sum(float(p['visit_hours']) for p in chosen)
        distance = km_between(origin, chosen[0])
        distance += sum(km_between(a, b) for a, b in zip(chosen, chosen[1:]))
        hours = visit + distance / 40.0
        match = sum(p['score'] for p in chosen) / (2 * len(chosen)) * 100
        # Absolute number of matching preference attributes rewards richer itineraries.
        sightseeing_value = sum(p['score'] for p in chosen) + 0.25 * len(chosen)
        return cost, visit, distance, hours, match, sightseeing_value

    class ItineraryProblem(ElementwiseProblem):
        def __init__(self):
            super().__init__(n_var=n + 1, n_obj=5, n_ieq_constr=2,
                             xl=np.zeros(n + 1), xu=np.ones(n + 1))
        def _evaluate(self, x, out, *args, **kwargs):
            cost, visit, distance, hours, match, value = evaluate(decode(x))
            out['F'] = [cost, distance, -match, -value, -distance]
            out['G'] = [cost - budget, hours - available_hours]

    result = minimize(ItineraryProblem(), NSGA2(pop_size=120, eliminate_duplicates=True),
                      ('n_gen', 120), seed=42, verbose=False)
    if result.X is None:
        raise ValueError('No feasible itinerary found with the selected must-visit places. Increase budget or available hours, or remove a place.')

    candidates = {}
    for x in np.atleast_2d(result.X):
        chosen = decode(x)
        cost, visit, distance, hours, match, value = evaluate(chosen)
        if cost > budget + 1e-7 or hours > available_hours + 1e-7:
            continue
        key = tuple(int(p['place_id']) for p in chosen)
        candidates[key] = {
            'destinations': [{'place_id': int(p['place_id']), 'place_name': str(p['place_name']),
                              'lat': float(p['lat']), 'lon': float(p['lon'])} for p in chosen],
            'destination_count': len(chosen),
            'destination_cost_usd': round(cost, 2),
            'visit_hours': round(visit, 2),
            'straight_line_km': round(distance, 2),
            'estimated_total_hours_proxy': round(hours, 2),
            'preference_match_percent': round(match, 1),
            'sightseeing_value': round(value, 2)
        }
    routes = list(candidates.values())
    if not routes:
        raise ValueError('No feasible itinerary found.')

    # Prefer distinct alternatives where possible; return labels in a stable order.
    selection = [
        ('best_preference_match', sorted(routes, key=lambda r: (-r['preference_match_percent'], -r['sightseeing_value'], r['straight_line_km']))),
        ('shortest_straight_line', sorted(routes, key=lambda r: (r['straight_line_km'], -r['sightseeing_value']))),
        ('longest_straight_line', sorted(routes, key=lambda r: (-r['straight_line_km'], -r['sightseeing_value'])))
    ]
    used = set()
    options = []
    for label, ranked in selection:
        picked = next((r for r in ranked if tuple(p['place_id'] for p in r['destinations']) not in used), ranked[0])
        used.add(tuple(p['place_id'] for p in picked['destinations']))
        options.append({'option': label, **picked})
    return {
        'algorithm': 'NSGA-II (pymoo)',
        'limitations': [
            'Two to six destinations per itinerary',
            'Distance is straight-line, not road distance',
            '40 km/h is an assumed travel-time proxy, not an ETA',
            'Costs exclude transport, accommodation and food',
            'Sightseeing value is a hand-designed objective, not measured satisfaction',
            'Solutions are approximate; no global optimum guarantee'
        ],
        'must_visit_places': requested,
        'pareto_routes_found': len(routes),
        'options': options
    }
