"""Load the trained Random Forest v2 and test a next-day heavy-rain prediction.
This is a historical replay, NOT a current forecast or disaster warning.
"""
from pathlib import Path
import joblib
import numpy as np
import pandas as pd

BASE = Path(__file__).resolve().parent
MODEL_PATH = BASE / 'hazard_ml' / 'model_outputs' / 'weather_risk_model_v2.joblib'
DATA_PATH = BASE / 'hazard_ml' / 'historical_weather.csv'

bundle = joblib.load(MODEL_PATH)  # Only load files you created/trust.
model = bundle['model']
features = bundle['features']
threshold = float(bundle['probability_threshold'])
df = pd.read_csv(DATA_PATH, parse_dates=['date'])
df = df.sort_values(['location', 'date'])

# Replay a historical date that was not used for training (2025).
# Observed weather from that date predicts whether the FOLLOWING day is heavy rain.
example = df[(df['location'] == 'Kandy') & (df['date'] == pd.Timestamp('2025-10-01'))]
if example.empty:
    raise ValueError('Historical example Kandy on 2025-10-01 not found')
row = example.iloc[0].copy()
date = row['date']
row['month_sin'] = np.sin(2 * np.pi * date.month / 12)
row['month_cos'] = np.cos(2 * np.pi * date.month / 12)
row['day_of_year_sin'] = np.sin(2 * np.pi * date.dayofyear / 365.25)
row['day_of_year_cos'] = np.cos(2 * np.pi * date.dayofyear / 365.25)
X = pd.DataFrame([{name: row[name] for name in features}])
prob = float(model.predict_proba(X)[0, 1])
next_day = date + pd.Timedelta(days=1)
actual_row = df[(df['location'] == 'Kandy') & (df['date'] == next_day)]
actual_mm = float(actual_row.iloc[0]['precipitation_sum']) if not actual_row.empty else None
print('MODEL LOADED SUCCESSFULLY')
print('Location: Kandy')
print('Observed input date:', date.date())
print('Predicted date:', next_day.date())
print('Probability of >=20 mm rain:', round(prob, 4))
print('Threshold:', threshold)
print('Screening result:', 'HIGHER RAINFALL CHANCE' if prob >= threshold else 'LOWER RAINFALL CHANCE')
print('Actual next-day precipitation (historical check):', actual_mm)
print('NOTE: Historical replay only; not a live forecast or flood/landslide prediction.')
