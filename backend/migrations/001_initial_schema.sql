BEGIN;

CREATE TABLE IF NOT EXISTS app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  display_name text NOT NULL,
  photo_url text,
  bio text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_sessions (
  token_hash char(64) PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS app_sessions_user_id_idx ON app_sessions(user_id);

CREATE TABLE IF NOT EXISTS planner_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  scheduled_at timestamptz NOT NULL,
  deadline timestamptz,
  priority text NOT NULL DEFAULT 'sedang' CHECK (priority IN ('tinggi','sedang','rendah')),
  category text,
  status text NOT NULL DEFAULT 'belum_selesai' CHECK (status IN ('belum_selesai','selesai')),
  reminder_enabled boolean NOT NULL DEFAULT false,
  reminder_minutes_before integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS planner_tasks_owner_schedule_idx ON planner_tasks(user_id, scheduled_at);

CREATE TABLE IF NOT EXISTS journal_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL DEFAULT '',
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  mood text,
  category text,
  tags text[] NOT NULL DEFAULT '{}',
  photo_urls text[] NOT NULL DEFAULT '{}',
  voice_note_url text,
  voice_note_duration_seconds double precision,
  voice_note_object_key text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS journal_entries_owner_date_idx ON journal_entries(user_id, entry_date DESC);

CREATE TABLE IF NOT EXISTS habits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  frequency text NOT NULL DEFAULT 'Setiap hari',
  active_days smallint[] NOT NULL DEFAULT '{1,2,3,4,5,6,7}',
  daily_target double precision,
  target_unit text,
  reminder_enabled boolean NOT NULL DEFAULT false,
  reminder_time text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS habit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  habit_id uuid NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
  local_date date NOT NULL,
  is_completed boolean NOT NULL DEFAULT false,
  progress double precision,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, habit_id, local_date)
);
CREATE INDEX IF NOT EXISTS habit_logs_owner_date_idx ON habit_logs(user_id, local_date DESC);

CREATE TABLE IF NOT EXISTS goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  category text,
  target_date timestamptz,
  target_value double precision,
  current_value double precision NOT NULL DEFAULT 0,
  unit text,
  color_hex text,
  status text NOT NULL DEFAULT 'Belum Dimulai' CHECK (status IN ('Belum Dimulai','Sedang Berjalan','Selesai')),
  progress_percent smallint NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE goals ADD COLUMN IF NOT EXISTS progress_percent smallint NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100);

CREATE TABLE IF NOT EXISTS goal_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  title text NOT NULL,
  is_completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  sort_order integer NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS goals_owner_date_idx ON goals(user_id, target_date);

COMMIT;
