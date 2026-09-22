import 'dart:convert';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

const _rpcStatuses = {
  'forbidden': 403,
  'card_not_found': 404,
  'program_not_available': 404,
  'reward_not_found': 404,
  'nothing_to_reverse': 404,
  'customer_limit_reached': 402,
  'punch_limit_reached': 402,
  'location_limit_reached': 402,
  'cooldown_active': 429,
  'membership_not_active': 409,
  'program_not_active': 409,
  'reward_already_redeemed': 409,
  'reward_not_available': 409,
  'reward_expired': 409,
  'reward_already_used': 409,
  'not_reversible': 409,
  'invalid_location': 400,
  'recovery_invalid': 410,
  'invalid_scan_code': 400,
  'scan_code_expired': 410,
  'rate_limited': 429,
};

Future<T> callRpc<T>(
  String name, [
  Map<String, dynamic> params = const {},
]) async {
  try {
    final data = await Supabase.instance.client.rpc(name, params: params);
    return data as T;
  } on PostgrestException catch (e) {
    final parts = e.message.split(':');
    final code = parts.first;
    throw AppException(
      _rpcStatuses.containsKey(code) ? code : 'internal',
      status: _rpcStatuses[code],
      data: code == 'cooldown_active' && parts.length > 1
          ? {'seconds_since_last': num.tryParse(parts[1])}
          : const {},
    );
  }
}

Future<Map<String, dynamic>> callRpcMap(
  String name, [
  Map<String, dynamic> params = const {},
]) async {
  final data = await callRpc<dynamic>(name, params);
  return Map<String, dynamic>.from(data as Map);
}

/// Stripe still uses Edge Functions because the secret key must stay server-side.
Future<Map<String, dynamic>> callFunction(
  String name, [
  Map<String, dynamic> body = const {},
]) async {
  try {
    final res = await Supabase.instance.client.functions.invoke(
      name,
      body: body,
    );
    return Map<String, dynamic>.from(res.data as Map);
  } on FunctionException catch (e) {
    final d = e.details;
    final map = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    throw AppException(
      map['error'] as String? ?? 'internal',
      status: e.status,
      data: map,
    );
  }
}

final _rng = Random.secure();

String _b64url(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

String randomUrlToken([int bytes = 32]) =>
    _b64url(List.generate(bytes, (_) => _rng.nextInt(256)));

String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();

String mintScanCode(String scanId, String scanSecretHex) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60;
  final secret = hex.decode(scanSecretHex);
  final sig = _b64url(
    Hmac(sha256, secret).convert(utf8.encode('$scanId.$exp')).bytes,
  );
  return 'pcq1.$scanId.$exp.$sig';
}
