class AppException implements Exception {
  AppException(this.code, {this.status, this.data = const {}});

  /// Machine code returned by the Edge Functions (e.g. `cooldown_active`).
  final String code;
  final int? status;
  final Map<String, dynamic> data;

  static const _messages = {
    'card_not_found': 'We could not find this card.',
    'program_not_available': 'This program is not available right now.',
    'customer_limit_reached': 'This business cannot accept new cards at the moment.',
    'punch_limit_reached': 'Monthly punch limit reached. Upgrade your plan to continue.',
    'cooldown_active': 'Punch recently added.',
    'rate_limited': 'Too many attempts. Please try again in a few minutes.',
    'reward_already_redeemed': 'This reward was already redeemed.',
    'reward_expired': 'This reward has expired.',
    'not_reversible': 'This punch can no longer be undone.',
    'reward_already_used': 'The reward from this punch was already used.',
    'scan_code_expired': 'This QR expired. Ask the customer to refresh their card.',
    'invalid_scan_code': 'This is not a PunchCardQR code.',
    'recovery_invalid': 'This recovery link is invalid or has expired.',
    'unauthorized': 'Please sign in again.',
    'forbidden': 'This card belongs to a different business.',
  };

  String get message => code == 'stripe_error' && data['message'] is String
      ? 'Stripe error: ${data['message']}'
      : _messages[code] ?? 'Something went wrong. Please try again.';

  @override
  String toString() => 'AppException($code)';
}
