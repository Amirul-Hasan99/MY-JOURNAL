# My Journal API

Node.js API for My Journal. Neon credentials stay in the server environment; never put `DATABASE_URL` in Flutter, `--dart-define`, or a committed file.

## Local setup

1. Install Node.js 20 or later.
2. Run `npm install` in this directory.
3. Copy `.env.example` to `.env`, then set `DATABASE_URL` from the Neon dashboard. The connection URL supplied in chat has been exposed; rotate its password in Neon and use the replacement here.
4. Run `npm run migrate` once to create the additive app tables.
5. Run `npm run verify:db` to perform a create/read/update/delete check inside a transaction that is rolled back.
6. Start the API with `npm run dev`.
7. From the Flutter project directory, start the app with:

   ```powershell
   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787
   ```

Open `http://127.0.0.1:8787/api/health` to check the API and Neon connection. The response contains only the connection status.

For an Android emulator, use `http://10.0.2.2:8787`; for a physical phone, use the computer's reachable LAN address and configure the firewall. Set exact trusted `CORS_ORIGINS` and HTTPS for deployment.

## API

- `POST /api/auth/sign-up`, `POST /api/auth/sign-in`, `POST /api/auth/sign-out`
- `GET/PATCH /api/me`
- CRUD: `/api/tasks`, `/api/journal`, `/api/habits`, `/api/goals`
- Habit activity: `GET /api/habit-logs`, `POST /api/habit-logs/toggle`
- `GET /api/health`

All user records are scoped to the authenticated session on the server. Passwords use bcrypt hashes; sessions are random opaque tokens stored as SHA-256 hashes with expiry. Forgot-password email delivery is intentionally reported as unconfigured until a mail provider is added.
