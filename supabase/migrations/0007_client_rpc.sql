-- PunchCardQR · 0007 · Client-facing RPC wrappers
-- These wrappers let the Flutter client use PostgREST RPC directly. Edge Functions are reserved for Stripe.

create or replace function _b64url(p_bytes bytea) returns text
language sql immutable set search_path = public as $$
  select rtrim(translate(encode(p_bytes, 'base64'), '+/', '-_'), '=')
$$;

create or replace function join_program_client(p_program_slug text) returns jsonb
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
    encode(gen_random_bytes(16), 'hex')
  );
  return v_res || jsonb_build_object('token', v_token);
end $$;

create or replace function get_public_card_client(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_hash text;
  v_card jsonb;
  v_scan jsonb;
begin
  if p_token !~ '^[A-Za-z0-9_-]{43}$' then
    raise exception 'card_not_found';
  end if;

  v_hash := encode(digest(p_token, 'sha256'), 'hex');
  v_card := get_public_card(v_hash);
  v_scan := get_scan_material(v_hash);

  return v_card || jsonb_build_object('scan', v_scan);
end $$;

create or replace function resolve_scan_client(p_scan_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_parts text[];
  v_scan_id text;
  v_exp bigint;
  v_sig text;
  v_owner uuid;
  v_res jsonb;
  v_secret_hex text;
  v_expected text;
begin
  v_owner := auth.uid();
  if v_owner is null then raise exception 'unauthorized'; end if;

  v_parts := string_to_array(coalesce(p_scan_code, ''), '.');
  if array_length(v_parts, 1) <> 4 or v_parts[1] <> 'pcq1' then
    raise exception 'invalid_scan_code';
  end if;

  v_scan_id := v_parts[2];
  v_exp := v_parts[3]::bigint;
  v_sig := v_parts[4];

  if extract(epoch from now())::bigint > v_exp then
    raise exception 'scan_code_expired';
  end if;

  v_res := resolve_scan(v_owner, v_scan_id);
  v_secret_hex := v_res ->> 'scan_secret_hex';
  v_expected := _b64url(hmac(convert_to(v_scan_id || '.' || v_exp::text, 'utf8'), decode(v_secret_hex, 'hex'), 'sha256'));

  if v_expected <> v_sig then
    raise exception 'invalid_scan_code';
  end if;

  return v_res - 'scan_secret_hex';
exception
  when invalid_text_representation then
    raise exception 'invalid_scan_code';
end $$;

create or replace function award_punch_client(p_membership uuid, p_idem text) returns jsonb
language sql security definer set search_path = public as $$
  select award_punch(auth.uid(), p_membership, p_idem)
$$;

create or replace function redeem_reward_client(p_earned_reward uuid, p_idem text) returns jsonb
language sql security definer set search_path = public as $$
  select redeem_reward(auth.uid(), p_earned_reward, p_idem)
$$;

create or replace function reverse_last_punch_client(p_membership uuid, p_idem text) returns jsonb
language sql security definer set search_path = public as $$
  select reverse_last_punch(auth.uid(), p_membership, p_idem)
$$;

create or replace function request_card_recovery_client(p_email text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  c record;
begin
  for c in select * from find_memberships_by_email(p_email) loop
    perform create_recovery_token(c.membership_id, encode(digest(_b64url(gen_random_bytes(32)), 'sha256'), 'hex'));
  end loop;
  return jsonb_build_object('ok', true);
end $$;

create or replace function claim_recovery_client(p_recovery_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_token text := _b64url(gen_random_bytes(32));
begin
  perform claim_recovery(
    encode(digest(p_recovery_token, 'sha256'), 'hex'),
    encode(digest(v_token, 'sha256'), 'hex'),
    _b64url(gen_random_bytes(9)),
    gen_random_bytes(32)
  );
  return jsonb_build_object('token', v_token);
end $$;

grant execute on function get_public_program(text), join_program_client(text), get_public_card_client(text), request_card_recovery_client(text), claim_recovery_client(text) to anon, authenticated;
grant execute on function resolve_scan_client(text), award_punch_client(uuid, text), redeem_reward_client(uuid, text), reverse_last_punch_client(uuid, text) to authenticated;
