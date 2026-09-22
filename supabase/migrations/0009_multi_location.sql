-- PunchCardQR · 0009 · Multi-location
-- `locations` and the `location_id` columns on loyalty_events/earned_rewards have existed
-- since 0001, and award_punch/redeem_reward already validate `p_location`, but nothing has
-- ever enforced `plan_limits.max_locations` or let the client attribute a punch/redeem to a
-- location. This migration adds that enforcement and threads `p_location` through the two
-- client-callable RPCs the Scan screen uses.

-- ───────────────────────── Enforce plan_limits.max_locations ─────────────────────────
-- Owners already have full CRUD on `locations` via the `locations_owner` RLS policy
-- (0002_rls.sql:51) — no new RPC surface needed, just a guard on insert.
create function _check_location_limit() returns trigger
language plpgsql as $$
declare
  v_plan  plan_tier;
  v_count int;
  v_max   int;
begin
  v_plan := _business_plan(new.business_id);
  select max_locations into v_max from plan_limits where plan = v_plan;
  select count(*) into v_count from locations where business_id = new.business_id;
  if v_count >= v_max then raise exception 'location_limit_reached'; end if;
  return new;
end $$;

create trigger locations_limit before insert on locations
  for each row execute function _check_location_limit();

-- ───────────────────────── Location-aware punch/redeem ─────────────────────────
drop function if exists award_punch_client(uuid, text);
create function award_punch_client(p_membership uuid, p_idem text, p_location uuid default null) returns jsonb
language sql security definer set search_path = public as $$
  select award_punch(auth.uid(), p_membership, p_idem, p_location)
$$;

drop function if exists redeem_reward_client(uuid, text);
create function redeem_reward_client(p_earned_reward uuid, p_idem text, p_location uuid default null) returns jsonb
language sql security definer set search_path = public as $$
  select redeem_reward(auth.uid(), p_earned_reward, p_idem, p_location)
$$;

grant execute on function award_punch_client(uuid, text, uuid), redeem_reward_client(uuid, text, uuid) to authenticated;
