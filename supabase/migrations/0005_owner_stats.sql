-- PunchCardQR · 0005 · Owner-facing stats (callable by signed-in owners, ownership re-checked inside)

create function dashboard_stats(p_business uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_since timestamptz := now() - interval '30 days'; v_tz text;
begin
  if not owns_business(p_business) then raise exception 'forbidden'; end if;
  select timezone into v_tz from businesses where id = p_business;

  return jsonb_build_object(
    'customers',        (select count(*) from loyalty_memberships where business_id = p_business),
    'active_customers', (select count(*) from loyalty_memberships
                          where business_id = p_business and last_activity_at >= v_since),
    'new_customers',    (select count(*) from loyalty_memberships
                          where business_id = p_business and joined_at >= v_since),
    'punches_total',    (select coalesce(sum(quantity), 0) from loyalty_events
                          where business_id = p_business and event_type in ('punch_added','punch_reversed')),
    'punches_30d',      (select coalesce(sum(quantity), 0) from loyalty_events
                          where business_id = p_business and created_at >= v_since
                            and event_type in ('punch_added','punch_reversed')),
    'rewards_earned',   (select count(*) from earned_rewards
                          where business_id = p_business and earned_at >= v_since and status <> 'cancelled'),
    'rewards_redeemed', (select count(*) from earned_rewards
                          where business_id = p_business and redeemed_at >= v_since),
    'rewards_redeemed_total', (select count(*) from earned_rewards
                          where business_id = p_business and status = 'redeemed'),
    'unredeemed_rewards', (select count(*) from earned_rewards
                          where business_id = p_business and status = 'available'),
    'punches_by_day', (select coalesce(jsonb_agg(jsonb_build_object('day', d.day, 'punches', coalesce(x.q, 0))
                                                 order by d.day), '[]')
        from (select generate_series((now() at time zone v_tz)::date - 29, (now() at time zone v_tz)::date, '1 day')::date as day) d
        left join (select (created_at at time zone v_tz)::date as day, sum(quantity) as q
                     from loyalty_events
                    where business_id = p_business and created_at >= v_since - interval '1 day'
                      and event_type in ('punch_added','punch_reversed') group by 1) x on x.day = d.day),
    'recent_activity', (select coalesce(jsonb_agg(a order by a.created_at desc), '[]') from (
        select e.event_type, e.quantity, e.created_at, c.customer_number,
               coalesce(nullif(c.first_name, ''), 'Customer #' || c.customer_number) as name
          from loyalty_events e
          join loyalty_memberships m on m.id = e.membership_id
          join customers c on c.id = m.customer_id
         where e.business_id = p_business
           and e.event_type in ('punch_added','membership_created','reward_redeemed','punch_reversed')
         order by e.created_at desc limit 8) a)
  );
end $$;

-- Current-month usage vs plan, for the billing screen.
create function billing_overview(p_business uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_plan plan_tier;
begin
  if not owns_business(p_business) then raise exception 'forbidden'; end if;
  v_plan := _business_plan(p_business);
  return jsonb_build_object(
    'plan', v_plan,
    'limits', (select to_jsonb(l) from plan_limits l where l.plan = v_plan),
    'customers', (select count(*) from loyalty_memberships where business_id = p_business),
    'punches_this_month', coalesce((select punches_issued from subscription_usage
        where business_id = p_business and period_start = date_trunc('month', now())::date), 0));
end $$;

revoke all on function dashboard_stats(uuid), billing_overview(uuid) from public, anon;
grant execute on function dashboard_stats(uuid), billing_overview(uuid) to authenticated, service_role;
