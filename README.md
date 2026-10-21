# Ceylon Path - Smart Tourist Routing and Risk Alert System

Flutter client and Python FastAPI backend for Sri Lankan destination planning, NSGA-II itinerary optimization, weather risk prediction, and hazard reports.

## Project structure

- `SmartTouristBackend/`: API source, Python dependency pins, destination/weather datasets, trained weather models, evaluation results, and research notebooks.
- `RP-J26-IT-368-it23145702-Anuji/RP-J26-IT-368-it23145702-Anuji/`: Flutter project root containing `pubspec.yaml`, application source, assets, and platform projects. The nested folder layout is intentional and preserved from the original project.

## Backend (PowerShell)

```powershell
cd SmartTouristBackend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
$env:HAZARD_ADMIN_API_KEY = '<your-own-private-admin-key>'
python -m uvicorn main:app --reload
```

Choose your own private administrator key; never commit it. The backend also supports a local `.hazard_admin_key` file, which Git ignores. The hazard database is local runtime data and is created automatically when hazard endpoints initialize it. Existing local reports are not distributed with the source.

API documentation: http://127.0.0.1:8000/docs

## Flutter client (second PowerShell terminal)

From the repository root:

```powershell
cd RP-J26-IT-368-it23145702-Anuji\RP-J26-IT-368-it23145702-Anuji
flutter pub get
flutter run -d chrome
```

Keep the backend running while using the app. Dependency manifests and the Flutter lockfile are included; virtual environments, caches, and build outputs are intentionally excluded. Dependency pins reflect the original development environment and may require a compatible Python version.

## Checks

With the backend running, execute `python backend_smoke_test.py` from `SmartTouristBackend` for non-destructive API checks. Live weather requires internet access. Route map lines represent itinerary legs rather than road navigation; hazard reports are unverified.
