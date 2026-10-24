# My Journal

Flutter app for daily planning, journaling, mood/habit tracking, goals, and insights. The visual system uses a sage/cream palette; the five primary tabs are **Beranda**, **Planner**, **Journal**, **Tracker**, and **Insight**.

## Run the local demo

```powershell
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
```

Demo mode uses local sample data and a temporary user named **Dania Sella**. It does not create a Neon account or synchronize data. Run `run.bat` and choose demo, or call `run.bat demo`.

## Neon backend

The Node API and PostgreSQL schema are in `backend/`. Set `DATABASE_URL` only in `backend/.env` (ignored by Git), rotate the connection password shared in chat, then follow `backend/README.md`. Migrations are additive and `npm run verify:db` exercises CRUD in a transaction that is rolled back. Start the app against the API with `--dart-define=API_BASE_URL=http://127.0.0.1:8787`. Demo mode remains local-only.

Email-based password recovery is not configured yet. Use HTTPS and set exact CORS origins before deploying the API.

## Checks

```powershell
flutter analyze
flutter test --no-pub --concurrency=1
flutter test --no-pub --concurrency=1 --dart-define=DEMO_MODE=true test\widget_test.dart
```
# BACKEND-MY-JOURNAL
