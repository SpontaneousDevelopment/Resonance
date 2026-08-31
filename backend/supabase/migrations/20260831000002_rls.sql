-- Row-Level Security.
--
-- Every table is deny-by-default and scoped to the authenticated user. This is
-- the only thing standing between one user's practice history and another's:
-- the client ships a publishable key by design, so key secrecy protects
-- nothing and these policies do all the work.
--
-- Voice practice is personal — a beginner's worst takes are exactly what they
-- would least like read — so there is no "public" or "shared" path anywhere in
-- this file. Community sharing, when it arrives, gets its own table with its
-- own explicit opt-in rather than a relaxation of these.

alter table public.profiles        enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.attempts        enable row level security;
alter table public.streak_state    enable row level security;
alter table public.daily_xp        enable row level security;

-- Force RLS even for the table owner, so a future function running as owner
-- cannot accidentally read across users.
alter table public.profiles        force row level security;
alter table public.lesson_progress force row level security;
alter table public.attempts        force row level security;
alter table public.streak_state    force row level security;
alter table public.daily_xp        force row level security;

-- profiles ------------------------------------------------------------------
create policy "own profile is readable"
  on public.profiles for select
  using ((select auth.uid()) = id);

create policy "own profile is insertable"
  on public.profiles for insert
  with check ((select auth.uid()) = id);

create policy "own profile is updatable"
  on public.profiles for update
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- lesson_progress -----------------------------------------------------------
create policy "own progress is readable"
  on public.lesson_progress for select
  using ((select auth.uid()) = user_id);

create policy "own progress is writable"
  on public.lesson_progress for insert
  with check ((select auth.uid()) = user_id);

create policy "own progress is updatable"
  on public.lesson_progress for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "own progress is deletable"
  on public.lesson_progress for delete
  using ((select auth.uid()) = user_id);

-- attempts ------------------------------------------------------------------
create policy "own attempts are readable"
  on public.attempts for select
  using ((select auth.uid()) = user_id);

create policy "own attempts are writable"
  on public.attempts for insert
  with check ((select auth.uid()) = user_id);

-- Deliberately no UPDATE policy. An attempt is a record of something that
-- happened; rewriting history is not a thing the app should be able to do,
-- and a rubric change recomputes locally rather than editing the past.
create policy "own attempts are deletable"
  on public.attempts for delete
  using ((select auth.uid()) = user_id);

-- streak_state --------------------------------------------------------------
create policy "own streak is readable"
  on public.streak_state for select
  using ((select auth.uid()) = user_id);

create policy "own streak is writable"
  on public.streak_state for insert
  with check ((select auth.uid()) = user_id);

create policy "own streak is updatable"
  on public.streak_state for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "own streak is deletable"
  on public.streak_state for delete
  using ((select auth.uid()) = user_id);

-- daily_xp ------------------------------------------------------------------
create policy "own xp is readable"
  on public.daily_xp for select
  using ((select auth.uid()) = user_id);

create policy "own xp is writable"
  on public.daily_xp for insert
  with check ((select auth.uid()) = user_id);

create policy "own xp is updatable"
  on public.daily_xp for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "own xp is deletable"
  on public.daily_xp for delete
  using ((select auth.uid()) = user_id);
