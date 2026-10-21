"""Tune next-day heavy-rain screening with chronological validation.
Run from any directory: python improve_weather_model.py
Does not overwrite the original trained model.
"""
from pathlib import Path
import json
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (precision_recall_fscore_support, confusion_matrix,
                             accuracy_score, average_precision_score)

BASE = Path(__file__).resolve().parent
SOURCE = BASE / 'hazard_ml' / 'historical_weather.csv'
OUT = BASE / 'hazard_ml' / 'model_outputs'
OUT.mkdir(parents=True, exist_ok=True)
THRESHOLD_MM = 20.0

if not SOURCE.exists():
    raise FileNotFoundError(f'Missing {SOURCE}')
df = pd.read_csv(SOURCE, parse_dates=['date'])
weather = ['temperature_2m_max', 'temperature_2m_min', 'precipitation_sum',
           'rain_sum', 'wind_speed_10m_max']
required = ['location', 'latitude', 'longitude', 'date', *weather]
if any(c not in df.columns for c in required):
    raise ValueError(f'Missing required columns: {set(required)-set(df.columns)}')
if df.duplicated(['location', 'date']).any():
    raise ValueError('Duplicate location/date rows found')
df = df.sort_values(['location', 'date']).copy()
for col in ['latitude', 'longitude', *weather]:
    df[col] = pd.to_numeric(df[col], errors='coerce')
g = df.groupby('location', sort=False)
df['next_day_precipitation_mm'] = g['precipitation_sum'].shift(-1)
df['next_date'] = g['date'].shift(-1)
df = df[(df['next_date']-df['date']).dt.days == 1].copy()
df['target'] = (df['next_day_precipitation_mm'] >= THRESHOLD_MM).astype(int)
df['month_sin'] = np.sin(2*np.pi*df['date'].dt.month/12)
df['month_cos'] = np.cos(2*np.pi*df['date'].dt.month/12)
df['day_of_year_sin'] = np.sin(2*np.pi*df['date'].dt.dayofyear/365.25)
df['day_of_year_cos'] = np.cos(2*np.pi*df['date'].dt.dayofyear/365.25)
features = ['latitude', 'longitude', *weather, 'month_sin', 'month_cos',
            'day_of_year_sin', 'day_of_year_cos']
df = df.dropna(subset=features + ['next_day_precipitation_mm'])
train = df[df['date'].dt.year == 2023]
valid = df[df['date'].dt.year == 2024]
test = df[df['date'].dt.year == 2025]
if any(x.empty for x in (train, valid, test)):
    raise ValueError('Need 2023 train, 2024 validation and 2025 test data')
if train['target'].nunique() != 2 or valid['target'].nunique() != 2:
    raise ValueError('Training and validation must contain both classes')

params = dict(n_estimators=250, max_depth=12, min_samples_leaf=5,
              class_weight='balanced_subsample', random_state=42, n_jobs=-1)
validation_model = RandomForestClassifier(**params)
validation_model.fit(train[features], train['target'])
valid_prob = validation_model.predict_proba(valid[features])[:, 1]

# Choose a threshold by validation F2 (recall emphasized), NOT test performance.
thresholds = np.round(np.arange(0.10, 0.81, 0.05), 2)
records = []
for t in thresholds:
    predictions = (valid_prob >= t).astype(int)
    p, r, f2, _ = precision_recall_fscore_support(
        valid['target'], predictions, average='binary', beta=2, zero_division=0)
    records.append({'threshold': float(t), 'precision': float(p),
                    'recall': float(r), 'f2': float(f2)})
validation_results = pd.DataFrame(records)
validation_results.to_csv(OUT / 'threshold_validation.csv', index=False)
chosen = sorted(records, key=lambda x: (-x['f2'], -x['precision'], x['threshold']))[0]['threshold']

# Final training uses 2023+2024, then 2025 is tested exactly once.
final_train = df[df['date'] < '2025-01-01']
final_model = RandomForestClassifier(**params)
final_model.fit(final_train[features], final_train['target'])
test_prob = final_model.predict_proba(test[features])[:, 1]

def score(pred):
    p, r, f1, _ = precision_recall_fscore_support(
        test['target'], pred, average='binary', zero_division=0)
    _, _, f2, _ = precision_recall_fscore_support(
        test['target'], pred, average='binary', beta=2, zero_division=0)
    return {'accuracy': round(float(accuracy_score(test['target'], pred)), 4),
            'precision': round(float(p), 4), 'recall': round(float(r), 4),
            'f1': round(float(f1), 4), 'f2': round(float(f2), 4),
            'confusion_matrix': confusion_matrix(test['target'], pred, labels=[0, 1]).tolist()}

original = (test_prob >= 0.50).astype(int)
improved = (test_prob >= chosen).astype(int)
results = {
    'task': 'Next-day rainfall >= 20mm; NOT verified flood/landslide prediction',
    'data_split': '2023 threshold-model training; 2024 threshold validation; 2023-24 final model training; 2025 held-out testing',
    'selected_probability_threshold': chosen,
    'validation_selection_metric': 'F2 (emphasizes recall)',
    'test_rows': len(test), 'test_heavy_rain_days': int(test['target'].sum()),
    'test_average_precision': round(float(average_precision_score(test['target'], test_prob)), 4),
    'threshold_0_50': score(original), 'selected_threshold': score(improved),
    'warning': 'Weather screening only; not an official hazard alert. Same-day observed features cannot be used before they are available.'
}
joblib.dump({'model': final_model, 'features': features, 'threshold_mm': THRESHOLD_MM,
             'probability_threshold': chosen, 'task': results['task']},
            OUT / 'weather_risk_model_v2.joblib')
(OUT / 'improved_evaluation_metrics.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
test[['location', 'date', 'next_day_precipitation_mm', 'target']].assign(
    predicted_probability=test_prob, prediction_at_050=original,
    prediction_at_selected_threshold=improved).to_csv(OUT / 'improved_test_predictions.csv', index=False)
print('IMPROVED MODEL TRAINING COMPLETED')
print('Selected threshold (using 2024 validation only):', chosen)
print('2025 test, original threshold 0.50:', results['threshold_0_50'])
print('2025 test, selected threshold:', results['selected_threshold'])
print('2025 average precision:', results['test_average_precision'])
print('Saved files to:', OUT)
