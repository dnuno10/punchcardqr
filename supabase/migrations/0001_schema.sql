-- PunchCardQR · 0001 · Schema
-- Only business owners exist in auth.users. Customers are plain rows, never auth users.

create extension if not exists pgcrypto;

-- ───────────────────────── Enums ─────────────────────────
create type plan_tier         as enum ('free', 'starter', 'pro');
create type sub_status        as enum ('active', 'trialing', 'past_due', 'canceled');
create type program_status    as enum ('draft', 'active', 'paused', 'archived');
create type reward_mode       as enum ('cycle', 'tiers');
create type reward_type       as enum ('free_item', 'percentage_discount', 'fixed_discount', 'custom');
create type membership_status as enum ('active', 'blocked', 'archived');
create type earned_status     as enum ('available', 'redeemed', 'expired', 'cancelled');
create type promotion_type    as enum ('bonus_punch', 'multiplier', 'signup_bonus');
create type event_type        as enum (
  'membership_created', 'punch_added', 'punch_reversed', 'signup_bonus',
  'promotion_bonus', 'reward_earned', 'reward_redeemed', 'reward_cancelled',
  'manual_adjustment'
);

-- ───────────────────────── Helpers ─────────────────────────
create function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ───────────────────────── Plans (data-driven limits) ─────────────────────────
create table plan_limits (
  plan                 plan_tier primary key,
  max_programs         int     not null,
  max_customers        int     not null,
  max_punches_month    int     not null,
  max_locations        int     not null,
  history_days         int,              -- null = unlimited
  allow_csv_export     boolean not null,
  allow_signup_bonus   boolean not null,
  allow_promotions     boolean not null,
  allow_tiers          boolean not null
);

insert into plan_limits values
  ('free',    1,   100,    200, 1,  30, false, false, false, false),
  ('starter', 1,  1000,   5000, 1, 365, true,  true,  false, false),
  ('pro',     5, 10000,  25000, 5, null, true, true,  true,  true);

-- ───────────────────────── Owners ─────────────────────────
create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text,
  email      text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_updated before update on profiles
  for each row execute function set_updated_at();

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ───────────────────────── Business ─────────────────────────
create table businesses (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references auth.users(id) on delete cascade,
  name             text not null,
  slug             text not null unique,
  logo_url         text,
  description      text,
  website          text,
  phone            text,
  instagram        text,
  timezone         text not null default 'UTC',
  currency         text not null default 'USD',
  customer_counter bigint not null default 0,  -- source of customers.customer_number
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index on businesses (owner_id);
create trigger businesses_updated before update on businesses
  for each row execute function set_updated_at();

create table locations (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  name        text not null,
  address     text,
  city        text,
  country     text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on locations (business_id);
create trigger locations_updated before update on locations
  for each row execute function set_updated_at();

-- ───────────────────────── Billing ─────────────────────────
create table subscriptions (
  id                     uuid primary key default gen_random_uuid(),
  business_id            uuid not null unique references businesses(id) on delete cascade,
  plan                   plan_tier   not null default 'free',
  status                 sub_status  not null default 'active',
  stripe_customer_id     text,
  stripe_subscription_id text,
  stripe_price_id        text,
  current_period_start   timestamptz,
  current_period_end     timestamptz,
  cancel_at_period_end   boolean not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create trigger subscriptions_updated before update on subscriptions
  for each row execute function set_updated_at();

create function handle_new_business() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into subscriptions (business_id) values (new.id);
  return new;
end $$;
create trigger on_business_created after insert on businesses
  for each row execute function handle_new_business();

create table subscription_usage (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references businesses(id) on delete cascade,
  period_start      date not null,                 -- first day of the calendar month
  customers_created int  not null default 0,
  punches_issued    int  not null default 0,
  programs_created  int  not null default 0,
  updated_at        timestamptz not null default now(),
  unique (business_id, period_start)
);

-- ───────────────────────── Programs ─────────────────────────
create table loyalty_programs (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references businesses(id) on delete cascade,
  name             text not null,
  slug             text not null unique,
  description      text,
  status           program_status not null default 'draft',
  reward_mode      reward_mode    not null default 'cycle',
  punches_required int  not null check (punches_required between 1 and 100),
  punch_term       text not null default 'punch',
  signup_bonus     int  not null default 0 check (signup_bonus between 0 and 5),
  cooldown_seconds int  not null default 30 check (cooldown_seconds >= 0),
  primary_color    text not null default '#6B4F3A',
  background_color text not null default '#FFFFFF',
  text_color       text not null default '#1F1F1F',
  punch_color      text,
  punch_icon_type  text not null default 'circle',
  punch_icon_url   text,
  cover_image_url  text,
  terms            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index on loyalty_programs (business_id);
create trigger programs_updated before update on loyalty_programs
  for each row execute function set_updated_at();

-- cycle mode: one active reward, earned every `punches_required` punches.
-- tiers mode: each reward is earned once when lifetime_punches crosses punch_threshold.
create table program_rewards (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references businesses(id) on delete cascade,
  program_id       uuid not null references loyalty_programs(id) on delete cascade,
  name             text not null,
  description      text,
  image_url        text,
  reward_type      reward_type not null default 'free_item',
  punch_threshold  int  not null check (punch_threshold > 0),
  discount_value   numeric,
  expiration_days  int check (expiration_days > 0),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index on program_rewards (program_id);
create trigger rewards_updated before update on program_rewards
  for each row execute function set_updated_at();

create table promotions (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references businesses(id) on delete cascade,
  program_id     uuid not null references loyalty_programs(id) on delete cascade,
  name           text not null,
  description    text,
  promotion_type promotion_type not null,
  bonus_quantity int,
  multiplier     numeric check (multiplier >= 1),
  starts_at      timestamptz not null,
  ends_at        timestamptz not null,
  days_of_week   int[],          -- 0 = Sunday … 6 = Saturday, in business timezone
  start_time     time,
  end_time       time,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index on promotions (program_id);
create trigger promotions_updated before update on promotions
  for each row execute function set_updated_at();

-- ───────────────────────── Customers & cards ─────────────────────────
create table customers (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references businesses(id) on delete cascade,
  customer_number   bigint not null,
  first_name        text,
  last_name         text,
  email             text,
  phone             text,
  birthday          date,
  marketing_consent boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (business_id, customer_number)
);
create index on customers (business_id, lower(email));
create trigger customers_updated before update on customers
  for each row execute function set_updated_at();

-- Two independent secrets per card:
--   public_token_hash : sha256 of the /c/{token} URL secret (view the card). Never stored in clear.
--   scan_id/scan_secret: the QR shown to the cashier is a short-lived HMAC(scan_secret, scan_id.exp),
--                        built and verified in Edge Functions, so a photo of the QR expires.
--   realtime_channel  : random id for Realtime Broadcast, unrelated to the token.
create table loyalty_memberships (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references businesses(id) on delete cascade,
  customer_id       uuid not null references customers(id) on delete cascade,
  program_id        uuid not null references loyalty_programs(id) on delete cascade,
  public_token_hash text not null unique,
  scan_id           text not null unique,
  scan_secret       bytea not null,
  realtime_channel  uuid not null default gen_random_uuid(),
  current_punches   int not null default 0 check (current_punches >= 0),
  lifetime_punches  int not null default 0 check (lifetime_punches >= 0),
  lifetime_rewards  int not null default 0 check (lifetime_rewards >= 0),
  status            membership_status not null default 'active',
  joined_at         timestamptz not null default now(),
  last_activity_at  timestamptz
);
create index on loyalty_memberships (business_id, last_activity_at desc);
create index on loyalty_memberships (customer_id);
create index on loyalty_memberships (program_id);

-- ───────────────────────── Ledger ─────────────────────────
create table loyalty_events (
  id                uuid primary key default gen_random_uuid(),
  business_id       uuid not null references businesses(id) on delete cascade,
  program_id        uuid not null references loyalty_programs(id) on delete cascade,
  membership_id     uuid not null references loyalty_memberships(id) on delete cascade,
  location_id       uuid references locations(id) on delete set null,
  event_type        event_type not null,
  quantity          int  not null default 0,
  balance_before    int  not null,
  balance_after     int  not null,
  reward_id         uuid references program_rewards(id) on delete set null,
  promotion_id      uuid references promotions(id) on delete set null,
  reverses_event_id uuid references loyalty_events(id),
  performed_by      uuid references auth.users(id) on delete set null,
  idempotency_key   text not null,
  metadata          jsonb not null default '{}',
  created_at        timestamptz not null default now(),
  unique (business_id, idempotency_key)
);
create index on loyalty_events (membership_id, created_at desc);
create index on loyalty_events (business_id, created_at desc);
create index on loyalty_events (business_id, event_type, created_at desc);
create unique index loyalty_events_one_reversal on loyalty_events (reverses_event_id)
  where reverses_event_id is not null;

create table earned_rewards (
  id                   uuid primary key default gen_random_uuid(),
  business_id          uuid not null references businesses(id) on delete cascade,
  membership_id        uuid not null references loyalty_memberships(id) on delete cascade,
  reward_id            uuid not null references program_rewards(id) on delete cascade,
  source_event_id      uuid references loyalty_events(id) on delete set null,
  status               earned_status not null default 'available',
  earned_at            timestamptz not null default now(),
  expires_at           timestamptz,
  redeemed_at          timestamptz,
  redeemed_by          uuid references auth.users(id) on delete set null,
  redeemed_location_id uuid references locations(id) on delete set null
);
create index on earned_rewards (membership_id, status);
create index on earned_rewards (business_id, status);
create index on earned_rewards (expires_at) where status = 'available';

create table audit_logs (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  owner_id    uuid references auth.users(id) on delete set null,
  action      text not null,
  entity_type text,
  entity_id   uuid,
  metadata    jsonb not null default '{}',
  created_at  timestamptz not null default now()
);
create index on audit_logs (business_id, created_at desc);
