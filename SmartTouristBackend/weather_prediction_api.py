"""Historical replay endpoint for the trained next-day heavy-rain Random Forest.
Only uses weather observed on the supplied date; NOT a live forecast or hazard warning.
"""
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix='/api/weather', tags=['Weather ML'])
BASE = Path(__file__).resolve().parent
MODEL_PATH = BASE / 'hazard_ml' / 'model_outputs' / 'weather_risk_model_v2.joblib'
DATA_PATH = BASE / 'hazard_ml' / 'historical_weather.csv'

@router.get('/historical-prediction')
def historical_prediction(location: str = Query('Kandy'), date: str = Query('2025-10-01')):
    try:
        requested_date = pd.Timestamp(date)
    except (ValueError, TypeError):
        raise HTTPException(status_code=422, detail='Use date YYYY-MM-DD')
    if requested_date.strftime('%Y-%m-%d') != date:
        raise HTTPException(status_code=422, detail='Use date YYYY-MM-DD')
    if not MODEL_PATH.is_file() or not DATA_PATH.is_file():
        raise HTTPException(status_code=500, detail='Model or historical weather dataset missing')
    # Only load a trusted model created by your own training script.
    bundle = joblib.load(MODEL_PATH)
    df = pd.read_csv(DATA_PATH, parse_dates=['date'])
    matched = df.loc[(df['location'].str.casefold() == location.strip().casefold()) & (df['date'] == requested_date)]
    if matched.empty:
        raise HTTPException(status_code=404, detail='No historical observation for that location and date')
    row = matched.iloc[0].copy()
    row['month_sin'] = np.sin(2 * np.pi * requested_date.month / 12)
    row['month_cos'] = np.cos(2 * np.pi * requested_date.month / 12)
    row['day_of_year_sin'] = np.sin(2 * np.pi * requested_date.dayofyear / 365.25)
    row['day_of_year_cos'] = np.cos(2 * np.pi * requested_date.dayofyear / 365.25)
    features = bundle['features']
    inputs = pd.DataFrame([{name: row[name] for name in features}], columns=features)
    if inputs.isna().any().any():
        raise HTTPException(status_code=422, detail='Historical record has missing model inputs')
    prob = float(bundle['model'].predict_proba(inputs)[0, 1])
    threshold = float(bundle['probability_threshold'])
    next_date = requested_date + pd.Timedelta(days=1)
    actual = df.loc[(df['location'].str.casefold() == location.strip().casefold()) & (df['date'] == next_date)]
    actual_mm = None if actual.empty else float(actual.iloc[0]['precipitation_sum'])
    return {
        'status': 'success', 'mode': 'historical_replay',
        'location': str(row['location']), 'input_date': date,
        'predicted_date': next_date.strftime('%Y-%m-%d'),
        'prediction_target': 'Next-day precipitation >= 20 mm',
        'model_score': round(prob, 4),
        'classification_threshold': threshold,
        'screening_result': 'HIGHER RAINFALL CHANCE' if prob >= threshold else 'LOWER RAINFALL CHANCE',
        'actual_next_day_precipitation_mm': actual_mm,
        'warning': 'Historical replay only. Model score is not a calibrated forecast or an official flood/landslide warning.'
    }
