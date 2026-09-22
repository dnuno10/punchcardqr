-- PunchCardQR · 0004 · Support for Edge Functions (rate limit, rotating scan QR, safe recovery)

-- ───────────────────────── Rate limiting ─────────────────────────
create table rate_limits (
  key          text primary key,
  window_start timestamptz not null default now(),
  hits         int not null default 0
);
alter table rate_limits enable row level security;  -- no policies: service_role only

-- Fixed window counter. Returns true when the call is allowed.
create function check_rate_limit(p_key text, p_max int, p_window_secs int) returns boolean
language plpgsql security definer set search_path = public as $$
declare v_hits int;
begin
  insert into rate_limits (key, window_start, hits) values (p_key, now(), 1)
  on conflict (key) do update set
    hits = case when rate_limits.window_start < now() - make_interval(secs => p_window_secs)
                then 1 else rate_limits.hits + 1 end,
    window_start = case when rate_limits.window_start < now() - make_interval(secs => p_window_secs)
                        then now() else rate_limits.window_start end
  returning hits into v_hits;
  return v_hits <= p_max;
end $$;

create function purge_rate_limits() returns void
language sql security definer set search_path = public as $$
  delete from rate_limits where window_start < now() - interval '1 day'
$$;

-- ───────────────────────── Rotating scan QR ─────────────────────────
-- The card page asks the Edge Function for a fresh 60-second code; the function needs the secret.
create function get_scan_material(p_token_hash text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m loyalty_memberships;
begin
  select * into m from loyalty_memberships
   where public_token_hash = p_token_hash and status = 'active';
  if m.id is null then raise exception 'card_not_found'; end if;
  return jsonb_build_object('scan_id', m.scan_id, 'scan_secret_hex', encode(m.scan_secret, 'hex'));
end $$;

-- ───────────────────────── Recovery (one-time link) ─────────────────────────
-- Requesting recovery does NOT invalidate the current link; only claiming the emailed
-- one-time link rotates the secrets. This prevents locking someone out by typing their email.
create table recovery_tokens (
  token_hash    text primary key,
  membership_id uuid not null references loyalty_memberships(id) on delete cascade,
  expires_at    timestamptz not null,
  used_at       timestamptz
);
alter table recovery_tokens enable row level security;

create function create_recovery_token(p_membership uuid, p_token_hash text) returns void
language sql security definer set search_path = public as $$
  insert into recovery_tokens (token_hash, membership_id, expires_at)
  values (p_token_hash, p_membership, now() + interval '30 minutes')
$$;

create function claim_recovery(
  p_recovery_hash text, p_new_token_hash text, p_new_scan_id text, p_new_scan_secret bytea
) returns void
language plpgsql security definer set search_path = public as $$
declare v_membership uuid;
begin
  update recovery_tokens set used_at = now()
   where token_hash = p_recovery_hash and used_at is null and expires_at > now()
  returning membership_id into v_membership;
  if v_membership is null then raise exception 'recovery_invalid'; end if;

  update loyalty_memberships set public_token_hash = p_new_token_hash,
         scan_id = p_new_scan_id, scan_secret = p_new_scan_secret
   where id = v_membership and status = 'active';
  if not found then raise exception 'card_not_found'; end if;
end $$;

-- ───────────────────────── Join page data ─────────────────────────
create function get_public_program(p_slug text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p loyalty_programs; b businesses; v_plan plan_tier;
begin
  select * into p from loyalty_programs where slug = p_slug and status = 'active';
  if p.id is null then raise exception 'program_not_available'; end if;
  select * into b from businesses where id = p.business_id;
  v_plan := _business_plan(b.id);
  return jsonb_build_object(
    'business', jsonb_build_object('name', b.name, 'logo_url', b.logo_url),
    'program', jsonb_build_object(
      'name', p.name, 'description', p.description, 'terms', p.terms,
      'punches_required', p.punches_required, 'punch_term', p.punch_term,
      'signup_bonus', case when (select allow_signup_bonus from plan_limits where plan = v_plan)
                           then p.signup_bonus else 0 end,
      'primary_color', p.primary_color, 'background_color', p.background_color,
      'text_color', p.text_color, 'punch_color', p.punch_color),
    'reward', (select jsonb_build_object('name', r.name, 'description', r.description)
                 from program_rewards r where r.program_id = p.id and r.is_active
                 order by r.punch_threshold limit 1),
    'show_branding', v_plan = 'free');
end $$;

-- ───────────────────────── Grants (service_role only) ─────────────────────────
revoke all on all functions in schema public from public, anon, authenticated;
grant execute on function owns_business(uuid) to authenticated;
grant execute on all functions in schema public to service_role;
