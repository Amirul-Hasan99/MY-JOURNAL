# Neon Setup

## Implemented

The project now contains a Node.js/Hono API in `backend/`, an additive Postgres schema, parameterized CRUD queries, owner scoping from verified sessions, and a database verification command that rolls back its temporary rows. Flutter uses the API when `DEMO_MODE` is off and keeps SharedPreferences for explicit demo mode.

The API uses the pooled Neon PostgreSQL connection through a server-side `pg` pool, following Neon's guidance for pooled connections and keeping database URLs in server secrets. See [Neon's connection pooling overview](https://neon.com/blog/postgres-support-case-recap) and [Node/Postgres integration example](https://neon.com/blog/authenticating-users-in-astro-using-neon-postgres-and-lucia-auth).

## Local configuration

1. Rotate the Neon password shared in chat.
2. In `backend/`, copy `.env.example` to `.env` and set `DATABASE_URL` to the replacement pooled connection URL. `.env` is ignored by Git.
3. Run `npm install`, `npm run migrate`, `npm run verify:db`, and `npm run dev`.
4. Run Flutter with `--dart-define=API_BASE_URL=http://127.0.0.1:8787`.

The schema migration has been applied to the provided Neon database. The read-only connectivity query returned database `My Journal` on PostgreSQL 18.6, the transactional CRUD verifier passed with all rows rolled back, and the local API health endpoint returned `database: connected`. Rotate the exposed password before continued use.

## Production requirements

- Deploy the API on HTTPS with exact `CORS_ORIGINS` values.
- Store `DATABASE_URL` in the backend host's secret manager, never in Flutter or a committed file.
- Set the Flutter API base URL to the deployed HTTPS API.
- Configure a real email provider before enabling password recovery.
- Use a separate Neon branch for staging and test multi-account ownership there.
