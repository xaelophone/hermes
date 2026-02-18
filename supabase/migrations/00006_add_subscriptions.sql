-- Subscription & usage tables for Free/Pro pricing
-- Tables: user_profiles, message_usage, processed_stripe_events

-- ============================================================
-- user_profiles
-- ============================================================
create table public.user_profiles (
  id                      uuid primary key references auth.users(id) on delete cascade,
  plan                    text not null default 'free' check (plan in ('free', 'pro')),
  stripe_customer_id      text,
  stripe_subscription_id  text,
  subscription_status     text not null default 'none'
                            check (subscription_status in ('none', 'active', 'trialing', 'past_due', 'canceled', 'incomplete', 'incomplete_expired')),
  billing_cycle_anchor    timestamptz,
  cancel_at_period_end    boolean not null default false,
  current_period_end      timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

alter table public.user_profiles enable row level security;

create policy "Users can read own profile"
  on public.user_profiles for select
  using (auth.uid() = id);

-- Server uses service key for writes — no insert/update policies needed

-- Reuse set_updated_at trigger from 00001
create trigger user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

-- Auto-create profile on new user signup
create or replace function public.create_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.create_user_profile();

-- Backfill existing users
insert into public.user_profiles (id)
  select id from auth.users
  on conflict do nothing;

-- ============================================================
-- message_usage
-- ============================================================
create table public.message_usage (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  project_id  uuid references public.projects(id) on delete set null,
  created_at  timestamptz not null default now()
);

create index message_usage_user_date_idx on public.message_usage(user_id, created_at);

alter table public.message_usage enable row level security;

create policy "Users can read own usage"
  on public.message_usage for select
  using (auth.uid() = user_id);

-- ============================================================
-- processed_stripe_events (idempotency)
-- ============================================================
create table public.processed_stripe_events (
  event_id      text primary key,
  event_type    text not null,
  processed_at  timestamptz not null default now()
);

create index processed_stripe_events_processed_at_idx
  on public.processed_stripe_events(processed_at);

alter table public.processed_stripe_events enable row level security;
-- No policies — server-only via service key

-- ============================================================
-- Helper functions for usage counting
-- ============================================================

-- Count messages sent by a user on a specific date (UTC)
create or replace function public.count_daily_messages(p_user_id uuid, p_date date)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.message_usage
  where user_id = p_user_id
    and created_at >= p_date::timestamptz
    and created_at < (p_date + interval '1 day')::timestamptz;
$$;

-- Count messages sent by a user since a billing period start
create or replace function public.count_period_messages(p_user_id uuid, p_period_start timestamptz)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.message_usage
  where user_id = p_user_id
    and created_at >= p_period_start;
$$;
