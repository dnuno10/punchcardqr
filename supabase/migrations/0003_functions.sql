-- PunchCardQR · 0003 · Transactional functions
-- All balance mutations happen here, inside one transaction, under a row lock on the membership.
-- Public functions are callable ONLY by service_role (Edge Functions). Edge Functions verify the
-- owner's JWT / the customer token and pass p_owner_id / hashes in; ownership is re-checked here.
-- Errors are raised as short codes (e.g. 'cooldown_active') that Edge Functions map to HTTP responses.

-- ───────────────────────── Internals ─────────────────────────

-- Effective plan: a subscription that is not active/trialing falls back to free.
create function _business_plan(p_business uuid) returns plan_tier
language sql stable security definer set search_path = public as $$
  select case when s.status in ('active', 'trialing') then s.plan else 'free' end
  from subscriptions s where s.business_id = p_business
$$;

create function _bump_usage(p_business uuid, p_customers int, p_punches int) returns void
language sql security definer set search_path = public as $$
  insert into subscription_usage (business_id, period_start, customers_created, punches_issued)
  values (p_business, date_trunc('month', now())::date, p_customers, p_punches)
  on conflict (business_id, period_start) do update set
    customers_created = subscription_usage.customers_created + excluded.customers_created,
    punches_issued    = subscription_usage.punches_issued    + excluded.punches_issued,
    updated_at        = now()
$$;

create function _membership_state(p_membership uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'current_punches',   m.current_punches,
    'lifetime_punches',  m.lifetime_punches,
    'punches_required',  p.punches_required,
    'reward_mode',       p.reward_mode,
    'available_rewards', (select count(*) from earned_rewards e
                           where e.membership_id = m.id and e.status = 'available'),
    'last_punch_at',     (select max(created_at) from loyalty_events ev
                           where ev.membership_id = m.id and ev.event_type = 'punch_added'
                             and not exists (select 1 from loyalty_events r where r.reverses_event_id = ev.id))
  )
  from loyalty_memberships m join loyalty_programs p on p.id = m.program_id
  where m.id = p_membership
$$;

-- Core ledger step. Caller must already have validated permissions.
-- Locks the membership, computes new balance, writes event(s), creates earned rewards.
create function _apply_punches(
  p_membership  uuid,
  p_qty         int,
  p_event_type  event_type,
  p_performed_by uuid,
  p_location    uuid,
  p_promotion   uuid,
  p_idem        text,
  p_meta        jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  m           loyalty_memberships;
  p           loyalty_programs;
  v_reward    program_rewards;
  v_before    int;
  v_after     int;
  v_life_b    int;
  v_life_a    int;
  v_earned    int := 0;
  v_event     uuid;
  r           program_rewards;
begin
  select * into m from loyalty_memberships where id = p_membership for update;
  if m.status <> 'active' then raise exception 'membership_not_active'; end if;
  select * into p from loyalty_programs where id = m.program_id;

  v_before := m.current_punches;
  v_life_b := m.lifetime_punches;
  v_life_a := v_life_b + p_qty;

  if p.reward_mode = 'cycle' then
    select * into v_reward from program_rewards
     where program_id = p.id and is_active order by punch_threshold limit 1;
    if v_reward.id is not null then
      v_earned := (v_before + p_qty) / p.punches_required;
      v_after  := (v_before + p_qty) % p.punches_required;   -- carry-over, never lose extras
    else
      v_after := v_before + p_qty;
    end if;
  else
    v_after := v_life_a;   -- tiers: balance mirrors lifetime
  end if;

  insert into loyalty_events (business_id, program_id, membership_id, location_id, event_type,
                              quantity, balance_before, balance_after, promotion_id,
                              performed_by, idempotency_key, metadata)
  values (m.business_id, m.program_id, m.id, p_location, p_event_type,
          p_qty, v_before, v_after, p_promotion, p_performed_by, p_idem, coalesce(p_meta, '{}'))
  returning id into v_event;

  if p.reward_mode = 'cycle' then
    for i in 1 .. v_earned loop
      insert into earned_rewards (business_id, membership_id, reward_id, source_event_id, expires_at)
      values (m.business_id, m.id, v_reward.id, v_event,
              case when v_reward.expiration_days is null then null
                   else now() + make_interval(days => v_reward.expiration_days) end);
    end loop;
  else
    for r in select * from program_rewards
              where program_id = p.id and is_active
                and punch_threshold > v_life_b and punch_threshold <= v_life_a loop
      insert into earned_rewards (business_id, membership_id, reward_id, source_event_id, expires_at)
      values (m.business_id, m.id, r.id, v_event,
              case when r.expiration_days is null then null
                   else now() + make_interval(days => r.expiration_days) end);
      v_earned := v_earned + 1;
    end loop;
  end if;

  if v_earned > 0 then
    insert into loyalty_events (business_id, program_id, membership_id, location_id, event_type,
                                quantity, balance_before, balance_after, performed_by,
                                idempotency_key, metadata)
    values (m.business_id, m.program_id, m.id, p_location, 'reward_earned',
            v_earned, v_after, v_after, p_performed_by, p_idem || ':reward',
            jsonb_build_object('source_event_id', v_event));
  end if;

  update loyalty_memberships set
    current_punches  = v_after,
    lifetime_punches = v_life_a,
    lifetime_rewards = lifetime_rewards + v_earned,
    last_activity_at = now()
  where id = m.id;

  if p_event_type = 'punch_added' then
    perform _bump_usage(m.business_id, 0, p_qty);
  end if;

  return jsonb_build_object('event_id', v_event, 'rewards_earned', v_earned,
                            'quantity', p_qty, 'state', _membership_state(m.id));
end $$;

-- ───────────────────────── Public: join ─────────────────────────
-- Token/scan secrets are generated in the Edge Function (crypto RNG); only the hash is stored.
create function join_program(
  p_program_slug text,
  p_token_hash   text,
  p_scan_id      text,
  p_scan_secret  bytea,
  p_idem         text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  p          loyalty_programs;
  b          businesses;
  v_plan     plan_tier;
  lim        plan_limits;
  v_count    int;
  v_number   bigint;
  v_customer uuid;
  v_member   uuid;
  v_bonus    int := 0;
begin
  select * into p from loyalty_programs where slug = p_program_slug;
  if p.id is null or p.status <> 'active' then raise exception 'program_not_available'; end if;

  select * into b from businesses where id = p.business_id for update;  -- serializes customer_number
  v_plan := _business_plan(b.id);
  select * into lim from plan_limits where plan = v_plan;

  select count(*) into v_count from loyalty_memberships where business_id = b.id;
  if v_count >= lim.max_customers then raise exception 'customer_limit_reached'; end if;

  v_number := b.customer_counter + 1;
  update businesses set customer_counter = v_number where id = b.id;

  insert into customers (business_id, customer_number) values (b.id, v_number)
  returning id into v_customer;

  insert into loyalty_memberships (business_id, customer_id, program_id, public_token_hash, scan_id, scan_secret)
  values (b.id, v_customer, p.id, p_token_hash, p_scan_id, p_scan_secret)
  returning id into v_member;

  insert into loyalty_events (business_id, program_id, membership_id, event_type,
                              balance_before, balance_after, idempotency_key)
  values (b.id, p.id, v_member, 'membership_created', 0, 0, p_idem || ':created');

  perform _bump_usage(b.id, 1, 0);

  if lim.allow_signup_bonus and p.signup_bonus > 0 then
    v_bonus := p.signup_bonus;
    perform _apply_punches(v_member, v_bonus, 'signup_bonus', null, null, null,
                           p_idem || ':bonus', jsonb_build_object('signup', true));
  end if;

  return jsonb_build_object('signup_bonus', v_bonus, 'customer_number', v_number);
end $$;

-- ───────────────────────── Public: read card ─────────────────────────
-- Returns only display-safe data. No internal ids, contact info, owner or billing data.
create function get_public_card(p_token_hash text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  m loyalty_memberships;
  p loyalty_programs;
  b businesses;
  c customers;
  v_plan plan_tier;
begin
  select * into m from loyalty_memberships where public_token_hash = p_token_hash;
  if m.id is null or m.status = 'archived' then raise exception 'card_not_found'; end if;
  select * into p from loyalty_programs where id = m.program_id;
  select * into b from businesses where id = m.business_id;
  select * into c from customers where id = m.customer_id;
  v_plan := _business_plan(b.id);

  return jsonb_build_object(
    'blocked', m.status = 'blocked',
    'display_name', coalesce(nullif(c.first_name, ''), 'Customer #' || c.customer_number),
    'business', jsonb_build_object('name', b.name, 'logo_url', b.logo_url,
                                   'website', b.website, 'instagram', b.instagram),
    'program', jsonb_build_object(
      'name', p.name, 'description', p.description, 'terms', p.terms,
      'status', p.status, 'reward_mode', p.reward_mode,
      'punches_required', p.punches_required, 'punch_term', p.punch_term,
      'primary_color', p.primary_color, 'background_color', p.background_color,
      'text_color', p.text_color, 'punch_color', p.punch_color,
      'punch_icon_type', p.punch_icon_type, 'punch_icon_url', p.punch_icon_url,
      'cover_image_url', p.cover_image_url),
    'show_branding', v_plan = 'free',
    'current_punches', m.current_punches,
    'lifetime_punches', m.lifetime_punches,
    'realtime_channel', m.realtime_channel,
    'rewards_catalog', (select coalesce(jsonb_agg(jsonb_build_object(
          'name', r.name, 'description', r.description, 'image_url', r.image_url,
          'punch_threshold', r.punch_threshold) order by r.punch_threshold), '[]')
        from program_rewards r where r.program_id = p.id and r.is_active),
    'available_rewards', (select coalesce(jsonb_agg(jsonb_build_object(
          'name', r.name, 'description', r.description,
          'earned_at', e.earned_at, 'expires_at', e.expires_at) order by e.earned_at), '[]')
        from earned_rewards e join program_rewards r on r.id = e.reward_id
        where e.membership_id = m.id and e.status = 'available'
          and (e.expires_at is null or e.expires_at > now())),
    'activity', (select coalesce(jsonb_agg(a order by a.created_at desc), '[]') from (
        select ev.event_type, ev.quantity, ev.created_at
          from loyalty_events ev
         where ev.membership_id = m.id
           and ev.event_type in ('punch_added','signup_bonus','promotion_bonus','reward_earned',
                                 'reward_redeemed','punch_reversed','manual_adjustment')
           and ev.created_at > now() - make_interval(days =>
                 coalesce((select history_days from plan_limits where plan = v_plan), 36500))
         order by ev.created_at desc limit 20) a)
  );
end $$;

-- Realtime helper: lets the Edge Function look up the broadcast channel after a mutation.
create function membership_channel(p_membership uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select realtime_channel from loyalty_memberships where id = p_membership
$$;

-- ───────────────────────── Owner: resolve scan ─────────────────────────
-- Edge Function verifies the HMAC of the scan code using scan_secret returned here,
-- then calls the mutation functions with the membership id.
create function resolve_scan(p_owner_id uuid, p_scan_id text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  m loyalty_memberships;
  p loyalty_programs;
  c customers;
begin
  select * into m from loyalty_memberships where scan_id = p_scan_id;
  if m.id is null then raise exception 'card_not_found'; end if;
  if not exists (select 1 from businesses where id = m.business_id and owner_id = p_owner_id) then
    raise exception 'forbidden';
  end if;
  select * into p from loyalty_programs where id = m.program_id;
  select * into c from customers where id = m.customer_id;

  return jsonb_build_object(
    'membership_id', m.id,
    'scan_secret_hex', encode(m.scan_secret, 'hex'),
    'status', m.status,
    'display_name', coalesce(nullif(c.first_name, ''), 'Customer #' || c.customer_number),
    'program_name', p.name,
    'program_status', p.status,
    'state', _membership_state(m.id),
    'available_rewards', (select coalesce(jsonb_agg(jsonb_build_object(
          'earned_reward_id', e.id, 'name', r.name, 'earned_at', e.earned_at,
          'expires_at', e.expires_at) order by e.earned_at), '[]')
        from earned_rewards e join program_rewards r on r.id = e.reward_id
        where e.membership_id = m.id and e.status = 'available'
          and (e.expires_at is null or e.expires_at > now()))
  );
end $$;

-- ───────────────────────── Owner: award punch ─────────────────────────
create function award_punch(
  p_owner_id    uuid,
  p_membership  uuid,
  p_idem        text,
  p_location    uuid default null,
  p_manual      boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  m        loyalty_memberships;
  p        loyalty_programs;
  b        businesses;
  lim      plan_limits;
  v_existing loyalty_events;
  v_qty    int := 1;
  v_promo  promotions;
  v_promo_qty int;
  v_best_promo uuid;
  v_local  timestamp;
  v_used   int;
  v_last   timestamptz;
  v_res    jsonb;
begin
  select * into m from loyalty_memberships where id = p_membership;
  if m.id is null then raise exception 'card_not_found'; end if;
  select * into b from businesses where id = m.business_id;
  if b.owner_id <> p_owner_id then raise exception 'forbidden'; end if;

  -- Idempotent replay: same key returns the original outcome instead of punching twice.
  select * into v_existing from loyalty_events
   where business_id = b.id and idempotency_key = p_idem;
  if v_existing.id is not null then
    return jsonb_build_object('replayed', true, 'event_id', v_existing.id,
                              'quantity', v_existing.quantity, 'state', _membership_state(m.id));
  end if;

  -- Serialize per membership before checks that depend on latest state.
  perform 1 from loyalty_memberships where id = m.id for update;

  select * into p from loyalty_programs where id = m.program_id;
  if p.status <> 'active' then raise exception 'program_not_active'; end if;
  if m.status <> 'active' then raise exception 'membership_not_active'; end if;
  if p_location is not null and not exists
     (select 1 from locations where id = p_location and business_id = b.id and is_active) then
    raise exception 'invalid_location';
  end if;

  select * into lim from plan_limits where plan = _business_plan(b.id);

  if p_manual then
    v_qty := 1;
    v_res := _apply_punches(m.id, 1, 'manual_adjustment', p_owner_id, p_location, null, p_idem,
                            jsonb_build_object('manual', true));
    perform _audit(b.id, p_owner_id, 'manual_adjustment', 'membership', m.id, '{}');
    return v_res;
  end if;

  -- Cooldown against the last non-reversed punch.
  select max(ev.created_at) into v_last from loyalty_events ev
   where ev.membership_id = m.id and ev.event_type = 'punch_added'
     and not exists (select 1 from loyalty_events r where r.reverses_event_id = ev.id);
  if v_last is not null and v_last > now() - make_interval(secs => p.cooldown_seconds) then
    raise exception 'cooldown_active:%', ceil(extract(epoch from (now() - v_last)))::int;
  end if;

  -- Best active promotion (Pro only).
  if lim.allow_promotions then
    v_local := now() at time zone b.timezone;
    for v_promo in
      select * from promotions
       where program_id = p.id and is_active and promotion_type <> 'signup_bonus'
         and now() between starts_at and ends_at
         and (days_of_week is null or extract(dow from v_local)::int = any (days_of_week))
         and (start_time is null or end_time is null
              or v_local::time between start_time and end_time)
    loop
      v_promo_qty := case v_promo.promotion_type
        when 'multiplier'  then greatest(1, round(v_promo.multiplier)::int)
        when 'bonus_punch' then 1 + coalesce(v_promo.bonus_quantity, 0) end;
      if v_promo_qty > v_qty then v_qty := v_promo_qty; v_best_promo := v_promo.id; end if;
    end loop;
  end if;

  -- Monthly punch limit.
  select coalesce(punches_issued, 0) into v_used from subscription_usage
   where business_id = b.id and period_start = date_trunc('month', now())::date;
  if coalesce(v_used, 0) + v_qty > lim.max_punches_month then
    raise exception 'punch_limit_reached';
  end if;

  return _apply_punches(m.id, v_qty, 'punch_added', p_owner_id, p_location, v_best_promo, p_idem,
                        jsonb_build_object('base', 1, 'promotion_id', v_best_promo));
end $$;

-- ───────────────────────── Owner: redeem ─────────────────────────
create function redeem_reward(
  p_owner_id        uuid,
  p_earned_reward   uuid,
  p_idem            text,
  p_location        uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  e        earned_rewards;
  b        businesses;
  m        loyalty_memberships;
  v_existing loyalty_events;
begin
  select * into e from earned_rewards where id = p_earned_reward for update;
  if e.id is null then raise exception 'reward_not_found'; end if;
  select * into b from businesses where id = e.business_id;
  if b.owner_id <> p_owner_id then raise exception 'forbidden'; end if;

  select * into v_existing from loyalty_events
   where business_id = b.id and idempotency_key = p_idem;
  if v_existing.id is not null then
    return jsonb_build_object('replayed', true, 'state', _membership_state(e.membership_id));
  end if;

  if e.status = 'redeemed' then raise exception 'reward_already_redeemed'; end if;
  if e.status <> 'available' then raise exception 'reward_not_available'; end if;
  if e.expires_at is not null and e.expires_at <= now() then
    update earned_rewards set status = 'expired' where id = e.id;
    raise exception 'reward_expired';
  end if;
  if p_location is not null and not exists
     (select 1 from locations where id = p_location and business_id = b.id and is_active) then
    raise exception 'invalid_location';
  end if;

  select * into m from loyalty_memberships where id = e.membership_id;

  update earned_rewards set status = 'redeemed', redeemed_at = now(),
         redeemed_by = p_owner_id, redeemed_location_id = p_location
   where id = e.id;

  insert into loyalty_events (business_id, program_id, membership_id, location_id, event_type,
                              quantity, balance_before, balance_after, reward_id,
                              performed_by, idempotency_key, metadata)
  values (m.business_id, m.program_id, m.id, p_location, 'reward_redeemed',
          1, m.current_punches, m.current_punches, e.reward_id, p_owner_id, p_idem,
          jsonb_build_object('earned_reward_id', e.id));

  update loyalty_memberships set last_activity_at = now() where id = m.id;

  return jsonb_build_object('state', _membership_state(m.id));
end $$;

-- ───────────────────────── Owner: undo last punch ─────────────────────────
create function reverse_last_punch(p_owner_id uuid, p_membership uuid, p_idem text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  m        loyalty_memberships;
  b        businesses;
  ev       loyalty_events;
  v_cancelled int;
begin
  select * into m from loyalty_memberships where id = p_membership for update;
  if m.id is null then raise exception 'card_not_found'; end if;
  select * into b from businesses where id = m.business_id;
  if b.owner_id <> p_owner_id then raise exception 'forbidden'; end if;

  if exists (select 1 from loyalty_events where business_id = b.id and idempotency_key = p_idem) then
    return jsonb_build_object('replayed', true, 'state', _membership_state(m.id));
  end if;

  -- Latest balance-affecting event that has not been reversed.
  select * into ev from loyalty_events e
   where e.membership_id = m.id
     and e.event_type in ('punch_added', 'manual_adjustment')
     and not exists (select 1 from loyalty_events r where r.reverses_event_id = e.id)
   order by e.created_at desc limit 1;
  if ev.id is null then raise exception 'nothing_to_reverse'; end if;

  -- Only if nothing that depends on the balance happened afterwards.
  if exists (select 1 from loyalty_events later
              where later.membership_id = m.id and later.created_at > ev.created_at
                and later.event_type in ('punch_added','manual_adjustment','signup_bonus',
                                         'promotion_bonus','reward_redeemed','punch_reversed')) then
    raise exception 'not_reversible';
  end if;

  -- Rewards this punch unlocked must still be untouched.
  if exists (select 1 from earned_rewards where source_event_id = ev.id and status <> 'available') then
    raise exception 'reward_already_used';
  end if;

  update earned_rewards set status = 'cancelled'
   where source_event_id = ev.id and status = 'available';
  get diagnostics v_cancelled = row_count;

  insert into loyalty_events (business_id, program_id, membership_id, location_id, event_type,
                              quantity, balance_before, balance_after, reverses_event_id,
                              performed_by, idempotency_key, metadata)
  values (m.business_id, m.program_id, m.id, ev.location_id, 'punch_reversed',
          -ev.quantity, m.current_punches, ev.balance_before, ev.id, p_owner_id, p_idem,
          jsonb_build_object('cancelled_rewards', v_cancelled));

  update loyalty_memberships set
    current_punches  = ev.balance_before,
    lifetime_punches = greatest(0, lifetime_punches - ev.quantity),
    lifetime_rewards = greatest(0, lifetime_rewards - v_cancelled),
    last_activity_at = now()
  where id = m.id;

  if ev.event_type = 'punch_added' then
    perform _bump_usage(m.business_id, 0, -ev.quantity);
  end if;

  perform _audit(b.id, p_owner_id, 'punch_reversed', 'membership', m.id,
                 jsonb_build_object('event_id', ev.id));

  return jsonb_build_object('state', _membership_state(m.id));
end $$;

-- ───────────────────────── Recovery / maintenance ─────────────────────────
-- Rotates the view token and scan secret (lost link, leaked QR). Old URLs stop working.
create function rotate_membership_secrets(
  p_owner_id uuid, p_membership uuid,
  p_new_token_hash text, p_new_scan_id text, p_new_scan_secret bytea
) returns void
language plpgsql security definer set search_path = public as $$
begin
  update loyalty_memberships m set public_token_hash = p_new_token_hash,
         scan_id = p_new_scan_id, scan_secret = p_new_scan_secret
   from businesses b
   where m.id = p_membership and b.id = m.business_id and b.owner_id = p_owner_id;
  if not found then raise exception 'forbidden'; end if;
end $$;

-- Recovery by email (customer-initiated): finds cards by contact, rotates secrets, returns the
-- data the Edge Function needs to email a new link. Never reveals whether an email exists to the caller.
create function find_memberships_by_email(p_email text)
returns table (membership_id uuid, business_name text, program_name text)
language sql stable security definer set search_path = public as $$
  select m.id, b.name, p.name
    from customers c
    join loyalty_memberships m on m.customer_id = c.id and m.status = 'active'
    join loyalty_programs p on p.id = m.program_id
    join businesses b on b.id = m.business_id
   where lower(c.email) = lower(p_email)
$$;

create function set_customer_contact(
  p_token_hash text, p_first_name text, p_email text, p_phone text, p_birthday date, p_consent boolean
) returns void
language plpgsql security definer set search_path = public as $$
begin
  update customers c set first_name = nullif(trim(p_first_name), ''),
         email = nullif(lower(trim(p_email)), ''), phone = nullif(trim(p_phone), ''),
         birthday = p_birthday, marketing_consent = coalesce(p_consent, false)
    from loyalty_memberships m
   where m.public_token_hash = p_token_hash and c.id = m.customer_id;
  if not found then raise exception 'card_not_found'; end if;
end $$;

create function expire_rewards() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update earned_rewards set status = 'expired'
   where status = 'available' and expires_at is not null and expires_at <= now();
  get diagnostics n = row_count;
  return n;
end $$;

create function _audit(p_business uuid, p_owner uuid, p_action text, p_type text, p_entity uuid, p_meta jsonb)
returns void language sql security definer set search_path = public as $$
  insert into audit_logs (business_id, owner_id, action, entity_type, entity_id, metadata)
  values (p_business, p_owner, p_action, p_type, p_entity, coalesce(p_meta, '{}'))
$$;

-- ───────────────────────── Execute grants ─────────────────────────
-- Everything above is service_role only (Edge Functions). Clients never call these directly.
revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function owns_business(uuid) to authenticated;
grant execute on all functions in schema public to service_role;
