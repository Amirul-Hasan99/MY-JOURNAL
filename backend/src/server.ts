import { createHash, randomBytes } from 'node:crypto';
import { serve } from '@hono/node-server';
import bcrypt from 'bcryptjs';
import { Hono, type Context } from 'hono';
import { cors } from 'hono/cors';
import type { PoolClient } from 'pg';
import { pool } from './db.js';

type Variables = { userId: string; tokenHash: string };
type AppContext = Context<{ Variables: Variables }>;
const app = new Hono<{ Variables: Variables }>();
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const days = Math.min(90, Math.max(1, Number(process.env.SESSION_TTL_DAYS ?? 30)));

function isAllowedOrigin(origin: string): boolean {
  const configured = (process.env.CORS_ORIGINS ?? '')
    .split(',').map((value) => value.trim()).filter(Boolean);
  if (configured.includes(origin)) return true;
  if (process.env.NODE_ENV === 'production') return false;
  try {
    const url = new URL(origin);
    return url.protocol === 'http:' &&
      (url.hostname === 'localhost' || url.hostname === '127.0.0.1');
  } catch { return false; }
}

app.use('/api/*', cors({
  origin: (origin) => isAllowedOrigin(origin) ? origin : '',
  allowMethods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  maxAge: 600,
}));

app.use('/api/*', async (c, next) => {
  if (c.req.path === '/api/health' || c.req.path.startsWith('/api/auth/')) return next();
  const authorization = c.req.header('Authorization') ?? '';
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : '';
  if (!token || token.length > 200) return c.json({ message: 'Sesi tidak valid.' }, 401);
  const tokenHash = createHash('sha256').update(token).digest('hex');
  const result = await pool.query(
    `SELECT user_id FROM app_sessions WHERE token_hash = $1 AND expires_at > now()`,
    [tokenHash],
  );
  if (!result.rowCount) return c.json({ message: 'Sesi berakhir. Silakan masuk kembali.' }, 401);
  c.set('userId', result.rows[0].user_id as string);
  c.set('tokenHash', tokenHash);
  await next();
});

app.onError((error, c) => {
  console.error('Request failed:', error.name);
  return c.json({ message: 'Permintaan gagal diproses.' }, 500);
});

app.get('/api/health', async (c) => {
  try {
    await pool.query('SELECT 1');
    return c.json({ status: 'ok', database: 'connected' });
  } catch {
    return c.json({ status: 'error', database: 'unavailable' }, 503);
  }
});

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function profile(row: Record<string, unknown>) {
  return {
    id: row.id,
    auth_user_id: row.id,
    display_name: row.display_name,
    email: row.email,
    photo_url: row.photo_url,
    bio: row.bio,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

async function createSession(userId: string) {
  const token = randomBytes(32).toString('base64url');
  await pool.query(
    `INSERT INTO app_sessions(token_hash, user_id, expires_at)
     VALUES ($1, $2, now() + ($3 * interval '1 day'))`,
    [hashToken(token), userId, days],
  );
  return token;
}

app.post('/api/auth/sign-up', async (c) => {
  const body = await c.req.json<Record<string, unknown>>();
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (name.length < 2 || name.length > 100 || !/^\S+@\S+\.\S+$/.test(email) || password.length < 10) {
    return c.json({ message: 'Nama, email, atau kata sandi tidak memenuhi syarat.' }, 400);
  }
  try {
    const result = await pool.query(
      `INSERT INTO app_users(email, password_hash, display_name)
       VALUES ($1, $2, $3)
       RETURNING id, email, display_name, photo_url, bio, created_at, updated_at`,
      [email, await bcrypt.hash(password, 12), name],
    );
    const user = result.rows[0];
    const sessionToken = await createSession(user.id);
    return c.json({ session_token: sessionToken, user_id: user.id, profile: profile(user) }, 201);
  } catch (error) {
    if ((error as { code?: string }).code === '23505') return c.json({ message: 'Email sudah terdaftar.' }, 409);
    throw error;
  }
});

app.post('/api/auth/sign-in', async (c) => {
  const body = await c.req.json<Record<string, unknown>>();
  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const result = await pool.query(
    `SELECT id, email, password_hash, display_name, photo_url, bio, created_at, updated_at
     FROM app_users WHERE email = $1`, [email],
  );
  if (!result.rowCount || !(await bcrypt.compare(password, result.rows[0].password_hash))) {
    return c.json({ message: 'Email atau kata sandi salah.' }, 401);
  }
  const user = result.rows[0];
  const sessionToken = await createSession(user.id);
  return c.json({ session_token: sessionToken, user_id: user.id, profile: profile(user) });
});

app.post('/api/auth/sign-out', async (c) => {
  const authorization = c.req.header('Authorization') ?? '';
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : '';
  if (token) await pool.query('DELETE FROM app_sessions WHERE token_hash = $1', [hashToken(token)]);
  return c.json({ success: true });
});

app.post('/api/auth/forgot-password', (c) =>
  c.json({ message: 'Pemulihan kata sandi belum dikonfigurasi.' }, 501));

app.get('/api/me', async (c) => {
  const result = await pool.query(
    `SELECT id, email, display_name, photo_url, bio, created_at, updated_at
     FROM app_users WHERE id = $1`, [c.get('userId')],
  );
  if (!result.rowCount) return c.json({ message: 'Akun tidak ditemukan.' }, 404);
  return c.json(profile(result.rows[0]));
});

app.patch('/api/me', async (c) => {
  const body = await c.req.json<{
    display_name?: unknown;
    bio?: unknown;
    photo_url?: unknown;
  }>();
  const displayName = typeof body.display_name === 'string' ? body.display_name.trim() : undefined;
  const bio = typeof body.bio === 'string' ? body.bio.trim() : undefined;
  const photoUrl = typeof body.photo_url === 'string' ? body.photo_url : undefined;
  if (displayName !== undefined && (displayName.length < 2 || displayName.length > 100)) {
    return c.json({ message: 'Nama harus terdiri dari 2 sampai 100 karakter.' }, 400);
  }
  if (photoUrl !== undefined && (
    photoUrl.length > 4 * 1024 * 1024 + 64 ||
    !/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(photoUrl)
  )) {
    return c.json({ message: 'Foto profil tidak valid atau ukurannya terlalu besar.' }, 400);
  }
  const result = await pool.query(
    `UPDATE app_users SET
       display_name = COALESCE($1, display_name),
       bio = COALESCE($2, bio),
       photo_url = COALESCE($3, photo_url),
       updated_at = now()
     WHERE id = $4
     RETURNING id, email, display_name, photo_url, bio, created_at, updated_at`,
    [displayName ?? null, bio ?? null, photoUrl ?? null, c.get('userId')],
  );
  if (!result.rowCount) return c.json({ message: 'Akun tidak ditemukan.' }, 404);
  return c.json(profile(result.rows[0]));
});

const uuidOr404 = (id: string) => uuidPattern.test(id);
type JsonBody = Record<string, unknown>;
const own = (body: JsonBody, key: string) => Object.prototype.hasOwnProperty.call(body, key);

async function insertOwned(c: AppContext, table: string, allowed: string[]) {
  const body = await c.req.json<JsonBody>();
  const keys = allowed.filter((key) => own(body, key));
  if (!keys.includes('title') && !keys.includes('name')) return c.json({ message: 'Field wajib belum diisi.' }, 400);
  const columns = ['user_id', ...keys];
  const values = [c.get('userId'), ...keys.map((key) => body[key])];
  const params = values.map((_, index) => `$${index + 1}`).join(', ');
  const names = columns.map((column) => `"${column}"`).join(', ');
  const result = await pool.query(
    `INSERT INTO "${table}" (${names}) VALUES (${params}) RETURNING *`, values,
  );
  return c.json(result.rows[0], 201);
}

async function updateOwned(c: AppContext, table: string, allowed: string[], id: string) {
  if (!uuidOr404(id)) return c.json({ message: 'Data tidak ditemukan.' }, 404);
  const body = await c.req.json<JsonBody>();
  const keys = allowed.filter((key) => own(body, key));
  if (keys.length === 0) return c.json({ message: 'Tidak ada perubahan.' }, 400);
  const assignments = keys.map((key, index) => `"${key}" = $${index + 1}`);
  assignments.push('updated_at = now()');
  const values = [...keys.map((key) => body[key]), id, c.get('userId')];
  const result = await pool.query(
    `UPDATE "${table}" SET ${assignments.join(', ')}
     WHERE id = $${keys.length + 1} AND user_id = $${keys.length + 2} RETURNING *`, values,
  );
  return result.rowCount ? c.json(result.rows[0]) : c.json({ message: 'Data tidak ditemukan.' }, 404);
}

async function deleteOwned(c: AppContext, table: string, id: string) {
  if (!uuidOr404(id)) return c.json({ message: 'Data tidak ditemukan.' }, 404);
  const result = await pool.query(`DELETE FROM "${table}" WHERE id = $1 AND user_id = $2`, [id, c.get('userId')]);
  return result.rowCount ? c.body(null, 204) : c.json({ message: 'Data tidak ditemukan.' }, 404);
}

const taskFields = ['title','description','scheduled_at','deadline','priority','category','status','reminder_enabled','reminder_minutes_before'];
app.get('/api/tasks', async (c) => {
  const values: unknown[] = [c.get('userId')];
  let sql = 'SELECT * FROM planner_tasks WHERE user_id = $1';
  const date = c.req.query('date');
  const category = c.req.query('category');
  if (date) { values.push(date); sql += ` AND scheduled_at::date = $${values.length}::date`; }
  if (category) { values.push(category); sql += ` AND category = $${values.length}`; }
  sql += ' ORDER BY (status = \'selesai\'), priority, scheduled_at';
  return c.json((await pool.query(sql, values)).rows);
});
app.post('/api/tasks', (c) => insertOwned(c, 'planner_tasks', taskFields));
app.patch('/api/tasks/:id', (c) => updateOwned(c, 'planner_tasks', taskFields, c.req.param('id')));
app.delete('/api/tasks/:id', (c) => deleteOwned(c, 'planner_tasks', c.req.param('id')));

const journalFields = ['title','content','entry_date','mood','category','tags','photo_urls','voice_note_url','voice_note_duration_seconds','voice_note_object_key'];
app.get('/api/journal', async (c) => {
  const values: unknown[] = [c.get('userId')];
  let sql = 'SELECT * FROM journal_entries WHERE user_id = $1';
  const search = c.req.query('searchQuery')?.trim();
  const mood = c.req.query('moodFilter');
  const category = c.req.query('categoryFilter');
  if (search) {
    values.push(`%${search}%`);
    sql += ` AND (title ILIKE $${values.length} OR content ILIKE $${values.length} OR entry_date::text ILIKE $${values.length} OR EXISTS (SELECT 1 FROM unnest(tags) tag WHERE tag ILIKE $${values.length}))`;
  }
  if (mood) { values.push(mood); sql += ` AND mood = $${values.length}`; }
  if (category && category !== 'Semua') { values.push(category); sql += ` AND category = $${values.length}`; }
  sql += ' ORDER BY created_at DESC';
  return c.json((await pool.query(sql, values)).rows);
});
app.post('/api/journal', (c) => insertOwned(c, 'journal_entries', journalFields));
app.patch('/api/journal/:id', (c) => updateOwned(c, 'journal_entries', journalFields, c.req.param('id')));
app.delete('/api/journal/:id', (c) => deleteOwned(c, 'journal_entries', c.req.param('id')));

const habitFields = ['name','description','frequency','active_days','daily_target','target_unit','reminder_enabled','reminder_time','is_active'];
app.get('/api/habits', async (c) => c.json((await pool.query(
  'SELECT * FROM habits WHERE user_id = $1 ORDER BY created_at', [c.get('userId')],
)).rows));
app.post('/api/habits', (c) => insertOwned(c, 'habits', habitFields));
app.patch('/api/habits/:id', (c) => updateOwned(c, 'habits', habitFields, c.req.param('id')));
app.delete('/api/habits/:id', (c) => deleteOwned(c, 'habits', c.req.param('id')));

app.get('/api/habit-logs', async (c) => {
  const date = c.req.query('date');
  const values: unknown[] = [c.get('userId')];
  let sql = 'SELECT * FROM habit_logs WHERE user_id = $1';
  if (date) { values.push(date); sql += ` AND local_date = $${values.length}::date`; }
  sql += ' ORDER BY local_date DESC';
  return c.json((await pool.query(sql, values)).rows);
});
app.post('/api/habit-logs/toggle', async (c) => {
  const body = await c.req.json<{ habit_id?: string; local_date?: string }>();
  if (!body.habit_id || !uuidOr404(body.habit_id) || !body.local_date) return c.json({ message: 'Kebiasaan atau tanggal tidak valid.' }, 400);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const habit = await client.query('SELECT id FROM habits WHERE id = $1 AND user_id = $2', [body.habit_id, c.get('userId')]);
    if (!habit.rowCount) { await client.query('ROLLBACK'); return c.json({ message: 'Kebiasaan tidak ditemukan.' }, 404); }
    const result = await client.query(
      `INSERT INTO habit_logs(user_id, habit_id, local_date, is_completed)
       VALUES ($1,$2,$3,true)
       ON CONFLICT(user_id, habit_id, local_date)
       DO UPDATE SET is_completed = NOT habit_logs.is_completed, updated_at = now()
       RETURNING *`, [c.get('userId'), body.habit_id, body.local_date],
    );
    await client.query('COMMIT');
    return c.json(result.rows[0]);
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
});

const goalFields = ['title','description','category','target_date','target_value','current_value','progress_percent','unit','color_hex','status'];
async function goalsForUser(userId: string, id?: string) {
  const values: unknown[] = [userId];
  const where = id ? ` AND g.id = $${values.push(id)}` : '';
  return (await pool.query(
    `SELECT g.*, COALESCE(json_agg(json_build_object(
       'id', m.id, 'goal_id', m.goal_id, 'title', m.title,
       'is_completed', m.is_completed, 'completed_at', m.completed_at,
       'sort_order', m.sort_order) ORDER BY m.sort_order)
       FILTER (WHERE m.id IS NOT NULL), '[]'::json) AS milestones
     FROM goals g LEFT JOIN goal_milestones m ON m.goal_id = g.id
     WHERE g.user_id = $1${where} GROUP BY g.id ORDER BY g.target_date NULLS LAST`, values,
  )).rows;
}
app.get('/api/goals', async (c) => c.json(await goalsForUser(c.get('userId'))));
app.post('/api/goals', async (c) => {
  const body = await c.req.json<JsonBody>();
  if (typeof body.title !== 'string' || !body.title.trim()) return c.json({ message: 'Judul tujuan wajib diisi.' }, 400);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const keys = goalFields.filter((key) => own(body, key));
    const values = [c.get('userId'), ...keys.map((key) => body[key])];
    const cols = ['user_id', ...keys];
    const result = await client.query(
      `INSERT INTO goals (${cols.map((key) => `"${key}"`).join(',')})
       VALUES (${values.map((_, i) => `$${i+1}`).join(',')}) RETURNING id`, values,
    );
    await replaceMilestones(client, result.rows[0].id, Array.isArray(body.milestones) ? body.milestones : []);
    await client.query('COMMIT');
    return c.json((await goalsForUser(c.get('userId'), result.rows[0].id))[0], 201);
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
});
app.patch('/api/goals/:id', async (c) => {
  const id = c.req.param('id');
  if (!uuidOr404(id)) return c.json({ message: 'Tujuan tidak ditemukan.' }, 404);
  const body = await c.req.json<JsonBody>();
  const keys = goalFields.filter((key) => own(body, key));
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (keys.length) {
      const values = [...keys.map((key) => body[key]), id, c.get('userId')];
      const assignments = keys.map((key, index) => `"${key}" = $${index+1}`);
      assignments.push('updated_at = now()');
      const result = await client.query(
        `UPDATE goals SET ${assignments.join(',')} WHERE id = $${keys.length+1} AND user_id = $${keys.length+2} RETURNING id`, values,
      );
      if (!result.rowCount) { await client.query('ROLLBACK'); return c.json({ message: 'Tujuan tidak ditemukan.' }, 404); }
    } else {
      const exists = await client.query('SELECT id FROM goals WHERE id=$1 AND user_id=$2', [id, c.get('userId')]);
      if (!exists.rowCount) { await client.query('ROLLBACK'); return c.json({ message: 'Tujuan tidak ditemukan.' }, 404); }
    }
    if (Array.isArray(body.milestones)) await replaceMilestones(client, id, body.milestones);
    await client.query('COMMIT');
    return c.json((await goalsForUser(c.get('userId'), id))[0]);
  } catch (error) { await client.query('ROLLBACK'); throw error; }
  finally { client.release(); }
});
app.delete('/api/goals/:id', (c) => deleteOwned(c, 'goals', c.req.param('id')));

async function replaceMilestones(client: PoolClient, goalId: string, milestones: unknown[]) {
  await client.query('DELETE FROM goal_milestones WHERE goal_id = $1', [goalId]);
  for (const [index, item] of milestones.entries()) {
    const m = item as Record<string, unknown>;
    if (typeof m.title !== 'string' || !m.title.trim()) continue;
    const id = typeof m.id === 'string' && uuidOr404(m.id) ? m.id : undefined;
    await client.query(
      `INSERT INTO goal_milestones(id, goal_id, title, is_completed, completed_at, sort_order)
       VALUES (COALESCE($1::uuid, gen_random_uuid()),$2,$3,$4,$5,$6)`,
      [id ?? null, goalId, m.title.trim(), m.is_completed === true, m.completed_at ?? null, Number(m.sort_order ?? index)],
    );
  }
}

const port = Number(process.env.PORT ?? 8787);
serve({ fetch: app.fetch, port, hostname: process.env.HOST ?? '127.0.0.1' }, () => {
  console.log(`My Journal API listening on port ${port}`);
});
