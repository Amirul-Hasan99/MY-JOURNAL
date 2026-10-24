import { randomUUID } from 'node:crypto';
import { pool } from './db.js';

const client = await pool.connect();
const check = (condition: boolean, message: string) => {
  if (!condition) throw new Error(`Database verification failed: ${message}`);
};

try {
  await client.query('BEGIN');
  const user = await client.query(
    `INSERT INTO app_users(email, password_hash, display_name)
     VALUES ($1, 'verification-only', 'My Journal DB verification') RETURNING id`,
    [`verify-${randomUUID()}@example.invalid`],
  );
  const userId = user.rows[0].id as string;

  const task = await client.query(
    `INSERT INTO planner_tasks(user_id, title, scheduled_at)
     VALUES ($1, 'verify create', now()) RETURNING id`, [userId],
  );
  const taskId = task.rows[0].id as string;
  check((await client.query('SELECT id FROM planner_tasks WHERE id=$1 AND user_id=$2', [taskId, userId])).rowCount === 1, 'task read');
  await client.query(`UPDATE planner_tasks SET title='verify update' WHERE id=$1 AND user_id=$2`, [taskId, userId]);
  check((await client.query(`SELECT title FROM planner_tasks WHERE id=$1`, [taskId])).rows[0].title === 'verify update', 'task update');
  await client.query('DELETE FROM planner_tasks WHERE id=$1 AND user_id=$2', [taskId, userId]);
  check((await client.query('SELECT id FROM planner_tasks WHERE id=$1', [taskId])).rowCount === 0, 'task delete');

  const journal = await client.query(
    `INSERT INTO journal_entries(user_id, title, content, entry_date)
     VALUES ($1, 'verify journal', 'transaction-only', CURRENT_DATE) RETURNING id`, [userId],
  );
  check((await client.query('SELECT id FROM journal_entries WHERE id=$1 AND user_id=$2', [journal.rows[0].id, userId])).rowCount === 1, 'journal create/read');

  const habit = await client.query(
    `INSERT INTO habits(user_id, name) VALUES ($1, 'verify habit') RETURNING id`, [userId],
  );
  const log = await client.query(
    `INSERT INTO habit_logs(user_id, habit_id, local_date, is_completed)
     VALUES ($1, $2, CURRENT_DATE, true) RETURNING id`, [userId, habit.rows[0].id],
  );
  check((await client.query('SELECT id FROM habit_logs WHERE id=$1 AND user_id=$2', [log.rows[0].id, userId])).rowCount === 1, 'habit/log create/read');

  const goal = await client.query(
    `INSERT INTO goals(user_id, title) VALUES ($1, 'verify goal') RETURNING id`, [userId],
  );
  const milestone = await client.query(
    `INSERT INTO goal_milestones(goal_id, title) VALUES ($1, 'verify milestone') RETURNING id`, [goal.rows[0].id],
  );
  await client.query('UPDATE goal_milestones SET is_completed=true WHERE id=$1', [milestone.rows[0].id]);
  check((await client.query('SELECT is_completed FROM goal_milestones WHERE id=$1', [milestone.rows[0].id])).rows[0].is_completed === true, 'goal/milestone read/update');

  await client.query('ROLLBACK');
  console.log('Neon connectivity and CRUD transaction verified; all verification rows were rolled back.');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
  await pool.end();
}
