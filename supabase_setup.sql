-- Run this in Supabase Dashboard → SQL Editor → New Query, then click Run.
-- This sets up everything the landing page needs: two tables, locked-down
-- Row Level Security (so the public anon key can only INSERT, never read
-- other people's emails or feedback), and a safe way to show a real
-- "you're subscriber #N" count without exposing any actual email addresses.

-- 1. Waitlist signups table
-- email is unique (no duplicate spam rows) and format-checked at the DB level,
-- so garbage/duplicate submissions are rejected before they're stored.
create table if not exists waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  created_at timestamptz not null default now()
);

alter table waitlist_signups enable row level security;

-- Anyone (using the public anon key) can INSERT a signup...
create policy "Allow public insert on waitlist_signups"
  on waitlist_signups
  for insert
  to anon
  with check (true);

-- ...but nobody can SELECT/UPDATE/DELETE via the anon key (no policy = no access).
-- You can still see all rows yourself in the Supabase Table Editor (that uses your
-- service role, not the anon key), or in the SQL Editor.

-- 2. Feedback / feature-idea submissions table
create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  message text not null,
  email text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  created_at timestamptz not null default now()
);

alter table feedback enable row level security;

create policy "Allow public insert on feedback"
  on feedback
  for insert
  to anon
  with check (true);

-- 3. Privacy-safe signup count
-- This function runs with elevated privileges (security definer) so it CAN
-- read the table internally, but it only ever returns a number — never any
-- actual email addresses — so it's safe to expose to the public anon key.
create or replace function get_waitlist_count()
returns integer
language sql
security definer
set search_path = public
as $$
  select count(*)::integer from waitlist_signups;
$$;

-- Allow the public anon key to call this function
grant execute on function get_waitlist_count() to anon;

-- Done. To verify: Table Editor should show "waitlist_signups" and "feedback"
-- both with a small padlock/shield icon indicating RLS is ON.
