import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/supabase_service.dart';
import '../../business/data/owner_repository.dart';

/// Active + inactive locations for the owner's business. RLS (`locations_owner`) already
/// scopes this to the caller — no RPC layer needed for plain CRUD.
final locationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ctx = await ref.watch(ownerContextProvider.future);
  if (ctx == null) return const [];
  final rows = await ref.watch(supabaseProvider).from('locations')
      .select().eq('business_id', ctx.business['id']).order('created_at');
  return rows.cast<Map<String, dynamic>>();
});

/// Only the active ones — what the Scan screen's picker and punch attribution care about.
final activeLocationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final all = await ref.watch(locationsProvider.future);
  return all.where((l) => l['is_active'] == true).toList();
});

class LocationsRepository {
  LocationsRepository(this._ref);
  final Ref _ref;

  Future<void> create({required String businessId, required String name, String? address, String? city, String? country}) =>
      _ref.read(supabaseProvider).from('locations').insert({
        'business_id': businessId, 'name': name, 'address': address, 'city': city, 'country': country,
      });

  Future<void> update(String id, {required String name, String? address, String? city, String? country}) =>
      _ref.read(supabaseProvider).from('locations').update({
        'name': name, 'address': address, 'city': city, 'country': country,
      }).eq('id', id);

  Future<void> setActive(String id, bool active) =>
      _ref.read(supabaseProvider).from('locations').update({'is_active': active}).eq('id', id);
}

final locationsRepositoryProvider = Provider((ref) => LocationsRepository(ref));

/// Remembers which location a device's Scan screen is operating from, so a cashier
/// isn't asked to pick again every time they reopen the app.
class ScanLocationPrefs {
  static String _key(String businessId) => 'scan_location_$businessId';

  static Future<String?> get(String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(businessId));
  }

  static Future<void> set(String businessId, String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(businessId), locationId);
  }

  static Future<void> clear(String businessId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(businessId));
  }
}
