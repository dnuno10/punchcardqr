import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class MarketingSettings {
  MarketingSettings({
    required this.birthdayEnabled,
    required this.birthdayBonusPunches,
    required this.reactivationEnabled,
    required this.reactivationDays,
    required this.reactivationMessage,
  });

  factory MarketingSettings.fromJson(Map<String, dynamic> j) => MarketingSettings(
        birthdayEnabled: j['birthday_rewards_enabled'] as bool? ?? false,
        birthdayBonusPunches: j['birthday_bonus_punches'] as int? ?? 1,
        reactivationEnabled: j['reactivation_enabled'] as bool? ?? false,
        reactivationDays: j['reactivation_days'] as int? ?? 60,
        reactivationMessage: j['reactivation_message'] as String?,
      );

  final bool birthdayEnabled, reactivationEnabled;
  final int birthdayBonusPunches, reactivationDays;
  final String? reactivationMessage;
}

final marketingSettingsProvider = FutureProvider.autoDispose<MarketingSettings>((ref) async {
  final json = await callRpcMap('get_marketing_settings_client');
  return MarketingSettings.fromJson(json);
});

/// Customers who've opted in — the addressable audience for campaigns.
final marketingConsentCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = ref.watch(supabaseProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return 0;
  final business = await client.from('businesses').select('id').eq('owner_id', uid).order('created_at').limit(1).maybeSingle();
  if (business == null) return 0;
  final res = await client.from('customers').select('id')
      .eq('business_id', business['id']).eq('marketing_consent', true).count(CountOption.exact);
  return res.count;
});

class MarketingRepository {
  Future<void> update(MarketingSettings s) async {
    await callRpc<dynamic>('update_marketing_settings_client', {
      'p_birthday_enabled': s.birthdayEnabled,
      'p_birthday_bonus': s.birthdayBonusPunches,
      'p_reactivation_enabled': s.reactivationEnabled,
      'p_reactivation_days': s.reactivationDays,
      'p_reactivation_message': s.reactivationMessage,
    });
  }
}

final marketingRepositoryProvider = Provider((ref) => MarketingRepository());
