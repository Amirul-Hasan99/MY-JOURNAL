import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Pool } from 'pg';

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error('DATABASE_URL is required.');

const pool = new Pool({
  connectionString,
  max: 1,
  connectionTimeoutMillis: 15_000,
  ssl: { rejectUnauthorized: true },
});

try {
  const migrationPath = fileURLToPath(
    new URL('../migrations/001_initial_schema.sql', import.meta.url),
  );
  const sql = await readFile(migrationPath, 'utf8');
  await pool.query(sql);
  console.log('Database migration 001 applied successfully.');
} finally {
  await pool.end();
}
