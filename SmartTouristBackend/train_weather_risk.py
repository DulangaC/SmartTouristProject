"""Train a next-day heavy-rainfall screening model, NOT a disaster predictor.
Input: hazard_ml/historical_weather.csv from collect_historical_weather.py
Output: hazard_ml/model_outputs/ (model, metrics, test predictions)
"""
from pathlib import Path
import json
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_recall_fscore_support, confusion_matrix, classification_report
from sklearn.dummy import DummyClassifier

BASE = Path(__file__).resolve().parent
SOURCE = BASE / 'hazard_ml' / 'historical_weather.csv'
OUT = BASE / 'hazard_ml' / 'model_outputs'
OUT.mkdir(parents=True, exist_ok=True)
THRESHOLD_MM = 20.0  # illustrative threshold, NOT an official hazard-warning threshold

if not SOURCE.exists():
    raise FileNotFoundError(f'Cannot find {SOURCE}. Run collect_historical_weather.py first.')
df = pd.read_csv(SOURCE, parse_dates=['date'])
required = ['location','latitude','longitude','date','temperature_2m_max','temperature_2m_min','precipitation_sum','rain_sum','wind_speed_10m_max']
missing = [c for c in required if c not in df.columns]
if missing:
    raise ValueError(f'Missing CSV columns: {missing}')
if df.duplicated(['location','date']).any():
    raise ValueError('Duplicate location/date records found. Inspect the CSV.')
df = df.sort_values(['location','date']).copy()
weather = ['temperature_2m_max','temperature_2m_min','precipitation_sum','rain_sum','wind_speed_10m_max']
for c in weather:
    df[c] = pd.to_numeric(df[c], errors='coerce')
# Predict NEXT day's heavy rainfall, using only observations available today.
g = df.groupby('location', sort=False)
df['next_day_precipitation_mm'] = g['precipitation_sum'].shift(-1)
df['next_date'] = g['date'].shift(-1)
# Discard location series endpoints and any discontinuous dates.
df = df[(df['next_date'] - df['date']).dt.days == 1].copy()
df['target_heavy_rain_tomorrow'] = (df['next_day_precipitation_mm'] >= THRESHOLD_MM).astype(int)
df['month_sin'] = np.sin(2*np.pi*df['date'].dt.month/12)
df['month_cos'] = np.cos(2*np.pi*df['date'].dt.month/12)
df['day_of_year_sin'] = np.sin(2*np.pi*df['date'].dt.dayofyear/365.25)
df['day_of_year_cos'] = np.cos(2*np.pi*df['date'].dt.dayofyear/365.25)
features = ['latitude','longitude', *weather, 'month_sin','month_cos','day_of_year_sin','day_of_year_cos']
df = df.dropna(subset=features + ['next_day_precipitation_mm']).copy()
train = df[df['date'] < '2025-01-01'].copy()
test = df[df['date'] >= '2025-01-01'].copy()
if train.empty or test.empty:
    raise ValueError('Not enough records in 2023–24 training / 2025 testing periods.')
X_train, y_train = train[features], train['target_heavy_rain_tomorrow']
X_test, y_test = test[features], test['target_heavy_rain_tomorrow']
if y_train.nunique() < 2:
    raise ValueError('Training data contains only one target class; threshold needs review.')
model = RandomForestClassifier(n_estimators=250, max_depth=12, min_samples_leaf=5,
                               class_weight='balanced_subsample', random_state=42, n_jobs=-1)
model.fit(X_train, y_train)
baseline = DummyClassifier(strategy='most_frequent')
baseline.fit(X_train, y_train)
pred = model.predict(X_test)
prob = model.predict_proba(X_test)[:, list(model.classes_).index(1)]
base_pred = baseline.predict(X_test)

def scores(actual, predicted):
    p,r,f,_ = precision_recall_fscore_support(actual, predicted, average='binary', zero_division=0)
    return {'accuracy': round(float(accuracy_score(actual,predicted)),4),
            'precision_heavy_rain': round(float(p),4), 'recall_heavy_rain': round(float(r),4),
            'f1_heavy_rain': round(float(f),4),
            'confusion_matrix_0_1': confusion_matrix(actual,predicted,labels=[0,1]).tolist()}
metrics = {'task': 'Predict next-day precipitation >= 20 mm using prior-day observed weather',
           'disclaimer': 'Research screening experiment, NOT flood/landslide prediction or an official warning.',
           'threshold_mm': THRESHOLD_MM, 'train_period': '2023-2024', 'test_period': '2025',
           'train_rows': len(train), 'test_rows': len(test),
           'train_positive_count': int(y_train.sum()), 'test_positive_count': int(y_test.sum()),
           'random_forest': scores(y_test,pred), 'majority_class_baseline': scores(y_test,base_pred)}
joblib.dump({'model':model,'features':features,'threshold_mm':THRESHOLD_MM,
             'task':metrics['task']}, OUT / 'weather_risk_model.joblib')
(OUT / 'evaluation_metrics.json').write_text(json.dumps(metrics, indent=2), encoding='utf-8')
test[['location','date','next_day_precipitation_mm','target_heavy_rain_tomorrow']].assign(
    predicted_heavy_rain=pred, predicted_probability=prob).to_csv(OUT/'test_predictions.csv', index=False)
print('TRAINING COMPLETED')
print('Train rows:', len(train), '| Test rows:', len(test))
print('Heavy-rain examples in train:', int(y_train.sum()), '| test:', int(y_test.sum()))
print('\nRandom Forest:', metrics['random_forest'])
print('Majority-class baseline:', metrics['majority_class_baseline'])
print('\nClassification report:\n', classification_report(y_test,pred,zero_division=0))
print('Saved model and evaluation to:', OUT)
print('IMPORTANT: This model predicts next-day heavy rainfall, NOT actual disasters.')
