import 'dotenv/config';
import { Pool } from 'pg';

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error('DATABASE_URL is required in the backend runtime environment.');
}

export const pool = new Pool({
  connectionString,
  max: 5,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 15_000,
  ssl: { rejectUnauthorized: true },
});

pool.on('error', () => {
  // Do not log connection details or credentials.
  console.error('An idle PostgreSQL connection failed.');
});
