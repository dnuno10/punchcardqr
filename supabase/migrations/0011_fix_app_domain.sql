-- PunchCardQR · 0011 · Fix app domain in emailed links
-- The Flutter app is hosted at app.punchcardqr.com, not the marketing site's root
-- domain (punchcardqr.com). request_card_recovery_client and run_marketing_campaigns
-- (0010) hardcoded the wrong host — recreate them pointing at the real app.

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
      '<p>Here''s your card recovery link:</p><p><a href="https://app.punchcardqr.com/recover/%s">Recover my card</a></p>' ||
      '<p style="color:#6C7688;font-size:12px">This link expires in 30 minutes.</p>', v_token
    );
    perform _send_marketing_email(p_email, 'Recover your PunchCardQR card', v_html);
  end loop;
  return jsonb_build_object('ok', true);
end $$;

create or replace function run_marketing_campaigns() returns void
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
          '<p><a href="https://app.punchcardqr.com/recover">View my card</a></p>', s.birthday_bonus_punches
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
          '<p>%s</p><p><a href="https://app.punchcardqr.com/recover">View my card</a></p>',
          coalesce(s.reactivation_message, 'We miss you! Come back for your next reward.')
        );
        perform _send_marketing_email(c.email, 'We miss you', v_html);
        insert into marketing_sends (business_id, customer_id, campaign_type) values (s.business_id, c.id, 'reactivation');
      end loop;
    end if;
  end loop;
end $$;
