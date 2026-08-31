-- Does Row-Level Security actually isolate two users?
--
-- The client ships a publishable key by design, so key secrecy protects
-- nothing and these policies are the only thing between one person's practice
-- history and another's. Asserting the policies *exist* would prove nothing —
-- this asserts what they do, by acting as each user in turn.
--
-- Every statement runs inside a transaction. SET LOCAL outside one is silently
-- a no-op, which leaves the session connected as postgres — a superuser that
-- bypasses RLS entirely, making a broken policy look fine and a working one
-- look broken. That mistake cost a full debugging cycle when this was written.
--
--   supabase db reset && \
--     docker exec -e PGPASSWORD=postgres supabase_db_backend \
--       psql -U postgres -d postgres -f /tmp/rls_test.sql
--
-- Fails loudly: any wrong answer raises and aborts.

\set alice '11111111-1111-1111-1111-111111111111'
\set bob   '22222222-2222-2222-2222-222222222222'

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  (:'alice','00000000-0000-0000-0000-000000000000','authenticated',
   'authenticated','alice@test.local','x', now(), now(), now()),
  (:'bob','00000000-0000-0000-0000-000000000000','authenticated',
   'authenticated','bob@test.local','x', now(), now(), now())
on conflict (id) do nothing;

-- Alice records practice.
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

  insert into public.lesson_progress (user_id, lesson_id, unit_id, mastery_rank, attempts, best_score)
  values (:'alice','t1u3l1','t1u3',3,7,81);
  insert into public.attempts (id, user_id, lesson_id, recorded_at, duration_ms, score)
  values ('a1',:'alice','t1u3l1', now(), 3600, 81);

  do $$
  declare n int;
  begin
    select count(*) into n from public.lesson_progress;
    if n <> 1 then raise exception 'alice cannot see her own progress (saw %)', n; end if;
    select count(*) into n from public.attempts;
    if n <> 1 then raise exception 'alice cannot see her own attempts (saw %)', n; end if;
    raise notice 'ok  alice reads her own rows';
  end $$;
commit;

-- Bob can see none of it.
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

  do $$
  declare n int;
  begin
    select count(*) into n from public.lesson_progress;
    if n <> 0 then raise exception 'bob can read % of alice''s progress rows', n; end if;
    select count(*) into n from public.attempts;
    if n <> 0 then raise exception 'bob can read % of alice''s attempts', n; end if;
    raise notice 'ok  bob reads none of alice''s rows';
  end $$;

  -- Nor write as her.
  do $$
  begin
    insert into public.lesson_progress (user_id, lesson_id, unit_id)
    values ('11111111-1111-1111-1111-111111111111','forged','t1u3');
    raise exception 'bob forged a row as alice';
  exception
    when insufficient_privilege then raise notice 'ok  bob cannot write as alice';
    when others then
      if sqlstate = '42501' then raise notice 'ok  bob cannot write as alice';
      else raise; end if;
  end $$;

  -- Nor delete hers.
  do $$
  declare removed int;
  begin
    delete from public.attempts where user_id = '11111111-1111-1111-1111-111111111111';
    get diagnostics removed = row_count;
    if removed > 0 then raise exception 'bob deleted % of alice''s attempts', removed; end if;
    raise notice 'ok  bob deletes none of alice''s attempts';
  end $$;
commit;

-- An attempt is a record of something that happened. There is no UPDATE policy
-- on purpose: a rubric change recomputes locally rather than rewriting history.
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';
  do $$
  declare changed int;
  begin
    update public.attempts set score = 100 where id = 'a1';
    get diagnostics changed = row_count;
    if changed > 0 then raise exception 'an attempt was rewritten'; end if;
    raise notice 'ok  attempts are immutable, even to their owner';
  end $$;
commit;

-- A signed-out caller sees nothing at all.
begin;
  set local role anon;
  set local request.jwt.claims = '{"role":"anon"}';
  do $$
  declare n int;
  begin
    select count(*) into n from public.lesson_progress;
    if n <> 0 then raise exception 'anon can read % progress rows', n; end if;
    raise notice 'ok  anon reads nothing';
  end $$;
commit;

-- Deleting the auth user must cascade. delete-account relies on this as its
-- backstop, so a table added later without a cascade is caught here.
begin;
  delete from auth.users where id = :'alice';
  do $$
  declare n int;
  begin
    select count(*) into n from public.lesson_progress
      where user_id = '11111111-1111-1111-1111-111111111111';
    if n <> 0 then raise exception 'progress survived the account being deleted'; end if;
    select count(*) into n from public.attempts
      where user_id = '11111111-1111-1111-1111-111111111111';
    if n <> 0 then raise exception 'attempts survived the account being deleted'; end if;
    raise notice 'ok  deleting the account cascades to every table';
  end $$;
commit;
