-- PunchCardQR · 0010 · Customer marketing (birthday rewards + re-engagement)
-- Customers are plain rows, never auth users (0001_schema.sql:2), so Supabase Auth's email
-- system (used for the owner OTP) can't reach them. This adds the only outbound-email path in
-- the project: pg_net calling Resend directly from Postgres, gated by a Vault secret the owner
-- provides. If the secret isn't set yet, sends no-op (logged) instead of breaking the cron.

create extension if not exists pg_net;

-- ───────────────────────── Settings & send log ─────────────────────────
create table marketing_settings (
  business_id             uuid primary key references businesses(id) on delete cascade,
  birthday_rewards_enabled boolean not null default false,
  birthday_bonus_punches   int     not null default 1,
  reactivation_enabled     boolean not null default false,
  reactivation_days        int     not null default 60,
  reactivation_message     text,
  updated_at               timestamptz not null default now()
);
alter table marketing_settings enable row level security;
create trigger marketing_settings_updated before update on marketing_settings
  for each row execute function set_updated_at();

create type marketing_campaign_type as enum ('birthday', 'reactivation');

create table marketing_sends (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references businesses(id) on delete cascade,
  customer_id    uuid not null references customers(id) on delete cascade,
  campaign_type  marketing_campaign_type not null,
  sent_at        timestamptz not null default now()
);
alter table marketing_sends enable row level security;
create index on marketing_sends (customer_id, campaign_type, sent_at desc);

grant select, insert, update on marketing_settings to authenticated;
create policy marketing_settings_owner on marketing_settings for all to authenticated
  using (owns_business(business_id)) with check (owns_business(business_id));

grant select on marketing_sends to authenticated;
create policy marketing_sends_read on marketing_sends for select to authenticated
  using (owns_business(business_id));

-- ───────────────────────── Client RPCs ─────────────────────────
create function get_marketing_settings_client() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_business uuid;
  v_row marketing_settings;
begin
  select id into v_business from businesses where owner_id = auth.uid() order by created_at limit 1;
  if v_business is null then raise exception 'business_not_found'; end if;
  select * into v_row from marketing_settings where business_id = v_business;
  if v_row.business_id is null then
    return jsonb_build_object(
      'birthday_rewards_enabled', false, 'birthday_bonus_punches', 1,
      'reactivation_enabled', false, 'reactivation_days', 60, 'reactivation_message', null
    );
  end if;
  return to_jsonb(v_row) - 'business_id' - 'updated_at';
end $$;

create function update_marketing_settings_client(
  p_birthday_enabled boolean, p_birthday_bonus int,
  p_reactivation_enabled boolean, p_reactivation_days int, p_reactivation_message text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_business uuid;
begin
  select id into v_business from businesses where owner_id = auth.uid() order by created_at limit 1;
  if v_business is null then raise exception 'business_not_found'; end if;
  insert into marketing_settings (
    business_id, birthday_rewards_enabled, birthday_bonus_punches,
    reactivation_enabled, reactivation_days, reactivation_message
  ) values (
    v_business, p_birthday_enabled, greatest(1, p_birthday_bonus),
    p_reactivation_enabled, greatest(7, p_reactivation_days), p_reactivation_message
  )
  on conflict (business_id) do update set
    birthday_rewards_enabled = excluded.birthday_rewards_enabled,
    birthday_bonus_punches   = excluded.birthday_bonus_punches,
    reactivation_enabled     = excluded.reactivation_enabled,
    reactivation_days        = excluded.reactivation_days,
    reactivation_message     = excluded.reactivation_message;
end $$;

grant execute on function get_marketing_settings_client(), update_marketing_settings_client(boolean, int, boolean, int, text)
  to authenticated;

-- ───────────────────────── Opt-in at signup ─────────────────────────
drop function if exists join_program(text, text, text, bytea, text);
create function join_program(
  p_program_slug text, p_token_hash text, p_scan_id text, p_scan_secret bytea, p_idem text,
  p_marketing_consent boolean default false, p_email text default null
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

  select * into b from businesses where id = p.business_id for update;
  v_plan := _business_plan(b.id);
  select * into lim from plan_limits where plan = v_plan;

  select count(*) into v_count from loyalty_memberships where business_id = b.id;
  if v_count >= lim.max_customers then raise exception 'customer_limit_reached'; end if;

  v_number := b.customer_counter + 1;
  update businesses set customer_counter = v_number where id = b.id;

  insert into customers (business_id, customer_number, marketing_consent, email)
  values (b.id, v_number, coalesce(p_marketing_consent, false), nullif(trim(p_email), ''))
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

drop function if exists join_program_client(text);
create function join_program_client(p_program_slug text, p_marketing_consent boolean default false, p_email text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_token text := _b64url(gen_random_bytes(32));
  v_scan_id text := _b64url(gen_random_bytes(9));
  v_scan_secret bytea := gen_random_bytes(32);
  v_res jsonb;
begin
  v_res := join_program(
    p_program_slug,
    encode(digest(v_token, 'sha256'), 'hex'),
    v_scan_id,
    v_scan_secret,
    encode(gen_random_bytes(16), 'hex'),
    p_marketing_consent,
    p_email
  );
  return v_res || jsonb_build_object('token', v_token);
end $$;

grant execute on function join_program_client(text, boolean, text) to anon, authenticated;

-- ───────────────────────── Sending (pg_net → Resend) ─────────────────────────
-- The owner runs `select vault.create_secret('<key>', 'resend_api_key');` once they have a
-- Resend API key. Until then this returns null and callers skip sending instead of failing.
create function _resend_api_key() returns text
language sql stable as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'resend_api_key' limit 1
$$;

create function _send_marketing_email(p_to text, p_subject text, p_html text) returns void
language plpgsql as $$
declare
  v_key text := _resend_api_key();
begin
  if v_key is null or p_to is null then return; end if;
  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
    body := jsonb_build_object(
      'from', 'PunchCardQR <notifications@punchcardqr.com>',
      'to', array[p_to], 'subject', p_subject, 'html', p_html
    )
  );
exception when others then
  -- Never let an email hiccup break a cron run or a customer-facing request.
  raise warning 'marketing email send failed: %', sqlerrm;
end $$;

-- Fixes a pre-existing gap: request_card_recovery_client (0007) minted a recovery token but
-- nothing ever emailed it to the customer. Now it does, best-effort, via the same helper.
create or replace function request_card_recovery_client(p_email text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  c record;
  v_token text;
  v_html text;
begin
  for c in select * from find_memberships_by_email(p_email) loop
    v_token := _b64url(gen_random_bytes(32));
    perform create_recovery_token(c.membership_id, encode(digest(v_token, 'sha256'), 'hex'));
    v_html := format(
      '<p>Here''s your card recovery link:</p><p><a href="https://punchcardqr.com/recover/%s">Recover my card</a></p>' ||
      '<p style="color:#6C7688;font-size:12px">This link expires in 30 minutes.</p>', v_token
    );
    perform _send_marketing_email(p_email, 'Recover your PunchCardQR card', v_html);
  end loop;
  return jsonb_build_object('ok', true);
end $$;

-- ───────────────────────── Campaign runner ─────────────────────────
create function run_marketing_campaigns() returns void
language plpgsql security definer set search_path = public as $$
declare
  s marketing_settings;
  c record;
  v_html text;
begin
  for s in select * from marketing_settings loop
    if s.birthday_rewards_enabled then
      for c in
        select cu.id, cu.email, m.id as membership_id
        from customers cu
        join loyalty_memberships m on m.customer_id = cu.id and m.status = 'active'
        join businesses b on b.id = cu.business_id
        where cu.business_id = s.business_id
          and cu.marketing_consent and cu.email is not null and cu.birthday is not null
          and extract(month from cu.birthday) = extract(month from now() at time zone b.timezone)
          and extract(day from cu.birthday) = extract(day from now() at time zone b.timezone)
          and not exists (
            select 1 from marketing_sends ms
            where ms.customer_id = cu.id and ms.campaign_type = 'birthday'
              and ms.sent_at > now() - interval '300 days'
          )
      loop
        perform _apply_punches(c.membership_id, s.birthday_bonus_punches, 'promotion_bonus', null, null, null,
                               'birthday:' || c.membership_id || ':' || extract(year from now()), '{"birthday": true}');
        v_html := format(
          '<p>Happy birthday! We added %s bonus punch(es) to your card.</p>' ||
          '<p><a href="https://punchcardqr.com/recover">View my card</a></p>', s.birthday_bonus_punches
        );
        perform _send_marketing_email(c.email, 'A birthday treat is waiting for you', v_html);
        insert into marketing_sends (business_id, customer_id, campaign_type) values (s.business_id, c.id, 'birthday');
      end loop;
    end if;

    if s.reactivation_enabled then
      for c in
        select cu.id, cu.email
        from customers cu
        join loyalty_memberships m on m.customer_id = cu.id and m.status = 'active'
        where cu.business_id = s.business_id
          and cu.marketing_consent and cu.email is not null
          and coalesce(m.last_activity_at, m.joined_at) < now() - make_interval(days => s.reactivation_days)
          and not exists (
            select 1 from marketing_sends ms
            where ms.customer_id = cu.id and ms.campaign_type = 'reactivation'
              and ms.sent_at > now() - make_interval(days => s.reactivation_days)
          )
      loop
        v_html := format(
          '<p>%s</p><p><a href="https://punchcardqr.com/recover">View my card</a></p>',
          coalesce(s.reactivation_message, 'We miss you! Come back for your next reward.')
        );
        perform _send_marketing_email(c.email, 'We miss you', v_html);
        insert into marketing_sends (business_id, customer_id, campaign_type) values (s.business_id, c.id, 'reactivation');
      end loop;
    end if;
  end loop;
end $$;

select cron.schedule('run-marketing-campaigns', '0 14 * * *', $$select public.run_marketing_campaigns()$$);
