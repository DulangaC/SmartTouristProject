"""Create NSGA-II evaluation figures from evaluate_nsga2.py outputs.
Run: .\\.venv\\Scripts\\python.exe plot_nsga2_results.py
"""
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

BASE = Path(__file__).resolve().parent
OUT = BASE / 'evaluation_results'
summary = pd.read_csv(OUT / 'summary.csv')
routes = pd.read_csv(OUT / 'routes.csv')
if summary.empty or routes.empty:
    raise ValueError('Evaluation CSVs are empty. Run evaluate_nsga2.py first.')
print('Scenarios:', len(summary), '| Routes:', len(routes))
print(summary[['scenario', 'status', 'runtime_seconds', 'distinct_displayed_routes']].to_string(index=False))

fig, ax = plt.subplots(figsize=(9, 5))
ax.bar(summary['scenario'], summary['runtime_seconds'])
ax.set(title='NSGA-II runtime by scenario', ylabel='Runtime (seconds)', xlabel='Scenario')
ax.tick_params(axis='x', rotation=15)
fig.tight_layout()
fig.savefig(OUT / 'runtime_by_scenario.png', dpi=160)
plt.close(fig)

fig, ax = plt.subplots(figsize=(9, 5))
for option, group in routes.groupby('option'):
    ax.scatter(group['cost_usd'], group['preference_match_percent'], label=option, s=70)
ax.set(title='Displayed itinerary cost vs preference match', xlabel='Destination cost (USD)', ylabel='Preference match (%)')
ax.legend()
fig.tight_layout()
fig.savefig(OUT / 'cost_vs_preference.png', dpi=160)
plt.close(fig)

fig, ax = plt.subplots(figsize=(9, 5))
for option, group in routes.groupby('option'):
    ax.scatter(group['straight_line_km'], group['time_proxy_hours'], label=option, s=70)
ax.set(title='Straight-line distance vs estimated time proxy', xlabel='Straight-line distance (km)', ylabel='Estimated total time proxy (hours)')
ax.legend()
fig.tight_layout()
fig.savefig(OUT / 'distance_vs_time.png', dpi=160)
plt.close(fig)
print('Saved 3 PNG graphs to:', OUT)
print('NOTE: These are descriptive plots of displayed results, not a baseline comparison or proof of optimality.')
