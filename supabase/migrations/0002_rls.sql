-- PunchCardQR · 0002 · Row Level Security
-- Owners read/write their own config through PostgREST.
-- Balances, events and rewards are READ-ONLY for owners: every mutation goes through
-- the SECURITY DEFINER functions in 0003 (called by Edge Functions with service_role).
-- anon gets nothing: customers only talk to Edge Functions.

create function owns_business(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from businesses where id = b and owner_id = auth.uid())
$$;

alter table profiles            enable row level security;
alter table businesses          enable row level security;
alter table locations           enable row level security;
alter table subscriptions       enable row level security;
alter table subscription_usage  enable row level security;
alter table loyalty_programs    enable row level security;
alter table program_rewards     enable row level security;
alter table promotions          enable row level security;
alter table customers           enable row level security;
alter table loyalty_memberships enable row level security;
alter table loyalty_events      enable row level security;
alter table earned_rewards      enable row level security;
alter table audit_logs          enable row level security;
alter table plan_limits         enable row level security;

-- Start from zero, then grant exactly what is needed.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, authenticated, public;

-- plan_limits: public catalogue for signed-in owners
grant select on plan_limits to authenticated;
create policy plan_limits_read on plan_limits for select to authenticated using (true);

-- profiles
grant select, update (full_name, avatar_url) on profiles to authenticated;
create policy profiles_self_read   on profiles for select to authenticated using (id = auth.uid());
create policy profiles_self_update on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- businesses
grant select, insert, update on businesses to authenticated;
create policy businesses_read   on businesses for select to authenticated using (owner_id = auth.uid());
create policy businesses_insert on businesses for insert to authenticated with check (owner_id = auth.uid());
create policy businesses_update on businesses for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- config tables: full owner CRUD
grant select, insert, update, delete on locations, loyalty_programs, program_rewards, promotions to authenticated;

create policy locations_owner on locations for all to authenticated
  using (owns_business(business_id)) with check (owns_business(business_id));
create policy programs_owner on loyalty_programs for all to authenticated
  using (owns_business(business_id)) with check (owns_business(business_id));
create policy rewards_owner on program_rewards for all to authenticated
  using (owns_business(business_id)) with check (owns_business(business_id));
create policy promotions_owner on promotions for all to authenticated
  using (owns_business(business_id)) with check (owns_business(business_id));

-- customers: owner can read and edit contact fields only
grant select on customers to authenticated;
grant update (first_name, last_name, email, phone, birthday, marketing_consent) on customers to authenticated;
create policy customers_read   on customers for select to authenticated using (owns_business(business_id));
create policy customers_update on customers for update to authenticated
  using (owns_business(business_id)) with check (owns_business(business_id));

-- read-only for owners (memberships column list keeps secrets out of reach)
grant select (id, business_id, customer_id, program_id, current_punches, lifetime_punches,
              lifetime_rewards, status, joined_at, last_activity_at)
  on loyalty_memberships to authenticated;
grant select on loyalty_events, earned_rewards, subscriptions, subscription_usage, audit_logs to authenticated;

create policy memberships_read on loyalty_memberships for select to authenticated using (owns_business(business_id));
create policy events_read      on loyalty_events      for select to authenticated using (owns_business(business_id));
create policy earned_read      on earned_rewards      for select to authenticated using (owns_business(business_id));
create policy subs_read        on subscriptions       for select to authenticated using (owns_business(business_id));
create policy usage_read       on subscription_usage  for select to authenticated using (owns_business(business_id));
create policy audit_read       on audit_logs          for select to authenticated using (owns_business(business_id));

-- Owners may deactivate a card directly (status only).
grant update (status) on loyalty_memberships to authenticated;
create policy memberships_status on loyalty_memberships for update to authenticated
  using (owns_business(business_id)) with check (owns_business(business_id));

-- Storage: buckets are public-read (logos/images shown on customer cards); writes limited to the
-- owner's own folder  business/{business_id}/...
insert into storage.buckets (id, name, public) values
  ('business-logos', 'business-logos', true),
  ('program-images', 'program-images', true),
  ('punch-icons',    'punch-icons',    true),
  ('reward-images',  'reward-images',  true)
on conflict (id) do nothing;

create policy owner_storage_write on storage.objects for all to authenticated
  using (
    bucket_id in ('business-logos','program-images','punch-icons','reward-images')
    and (storage.foldername(name))[1] = 'business'
    and owns_business(((storage.foldername(name))[2])::uuid)
  )
  with check (
    bucket_id in ('business-logos','program-images','punch-icons','reward-images')
    and (storage.foldername(name))[1] = 'business'
    and owns_business(((storage.foldername(name))[2])::uuid)
  );

-- RLS policies evaluate this as the calling user, so it must stay executable.
grant execute on function owns_business(uuid) to authenticated;
