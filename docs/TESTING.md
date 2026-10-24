# Testing — status 2026-10-23

## Checks run

- `npm install` in `backend/` — passed; npm reported 0 vulnerabilities at install time.
- `npm run typecheck` in `backend/` — passed.
- `flutter analyze --no-pub` — passed with no issues.
- `flutter test --no-pub --concurrency=1` — passed: four checks, one demo-only flow skipped.
- `flutter test --no-pub --concurrency=1 --dart-define=DEMO_MODE=true test\widget_test.dart` — passed: responsive welcome and demo sign-in/navigation across all five tabs.
- A read-only Neon query connected to database `My Journal` on PostgreSQL 18.6.
- `npm run migrate` — passed; additive app tables/indexes were created.
- `npm run verify:db` — passed on Neon. It created/read/updated/deleted a Planner task and exercised Journal, Habit, Habit Log, Goal, and Milestone storage inside a transaction, then rolled the transaction back.

The Neon connection URL was supplied in chat and is considered exposed. Rotate the database password in Neon before using the API beyond this verification. No connection URL is stored in the source files or `.env`.

## Not verified

- The browser-side live UI flow against the newly configured API could not be completed because the in-app browser denied re-access to the restarted localhost URL. Do not treat this as a UI E2E pass.
- Authenticated HTTP CRUD through the running API and cross-account isolation have not been E2E tested.
- Forgot-password email, production deployment/HTTPS/CORS, file storage, native microphone/notifications, home-screen widgets, and physical-device E2E remain unverified.
- The previous web production build attempt did not return a completion status; treat it as incomplete until rebuilt.
