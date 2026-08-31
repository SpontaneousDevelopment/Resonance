-- Server-side progress, mirroring the local Drift schema.
--
-- The device is the source of truth: everything here is a replica the client
-- pushes to, which is why every table carries the client's own identifiers and
-- why nothing on the server computes a score, a streak or a mastery level. The
-- rules live in the app's domain layer and are already tested there; a second
-- implementation in SQL would be a second place for them to disagree.
--
-- Not mirrored deliberately:
--   * outbox      — local queue plumbing, meaningless off-device
--   * energy      — session pacing that resets daily and is device-local

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  -- Set once, when anonymous progress is adopted into a new account. Lets the
  -- client tell "this account started as my device" from "this account already
  -- had history", which is the distinction the sign-in decision turns on.
  adopted_from_device boolean not null default false
);

create table if not exists public.lesson_progress (
  user_id uuid not null references auth.users on delete cascade,
  lesson_id text not null,
  unit_id text not null,
  mastery_rank int not null default 0 check (mastery_rank between 0 and 5),
  attempts int not null default 0 check (attempts >= 0),
  best_score int not null default 0 check (best_score between 0 and 100),
  last_promoted_on date,
  last_attempted_on date,
  updated_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);

create table if not exists public.attempts (
  -- The client's own attempt id. Makes the push idempotent: a retry after a
  -- timeout that actually succeeded inserts nothing rather than duplicating.
  id text not null,
  user_id uuid not null references auth.users on delete cascade,
  lesson_id text not null,
  recorded_at timestamptz not null,
  duration_ms int not null check (duration_ms >= 0),
  score int not null check (score between 0 and 100),
  clarity_score int check (clarity_score between 0 and 100),
  pace_score int check (pace_score between 0 and 100),
  plosive_score int check (plosive_score between 0 and 100),
  words_per_minute int,
  -- Transcript only. Recordings never leave the device, so there is no column
  -- here for one — the absence is the enforcement.
  transcript text,
  created_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.streak_state (
  user_id uuid primary key references auth.users on delete cascade,
  current_streak int not null default 0 check (current_streak >= 0),
  longest_streak int not null default 0 check (longest_streak >= 0),
  last_practice_day date,
  freezes_available int not null default 2 check (freezes_available >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_xp (
  user_id uuid not null references auth.users on delete cascade,
  day date not null,
  xp int not null default 0 check (xp >= 0),
  sessions_completed int not null default 0 check (sessions_completed >= 0),
  primary key (user_id, day)
);

-- Leagues will rank by weekly XP across users; this is the index that query
-- needs, and adding it now costs nothing.
create index if not exists daily_xp_day_idx on public.daily_xp (day);
create index if not exists attempts_user_recorded_idx
  on public.attempts (user_id, recorded_at desc);
