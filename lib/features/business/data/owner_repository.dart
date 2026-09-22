import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/ids.dart';

class OwnerContext {
  OwnerContext(this.business, this.program, this.reward);
  final Map<String, dynamic> business;
  final Map<String, dynamic>? program;
  final Map<String, dynamic>? reward;
}

/// The signed-in owner's business, first program and its reward. Null until onboarding is done.
final ownerContextProvider = FutureProvider.autoDispose<OwnerContext?>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;

  final business = await client.from('businesses').select().eq('owner_id', uid).maybeSingle();
  if (business == null) return null;
  final program = await client
      .from('loyalty_programs').select().eq('business_id', business['id'])
      .order('created_at').limit(1).maybeSingle();
  final reward = program == null
      ? null
      : await client.from('program_rewards').select().eq('program_id', program['id'])
          .eq('is_active', true).order('punch_threshold').limit(1).maybeSingle();
  return OwnerContext(business, program, reward);
});

class NewProgramInput {
  NewProgramInput({
    required this.businessName,
    required this.programName,
    required this.punchesRequired,
    required this.rewardName,
    required this.punchTerm,
    required this.signupBonus,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.punchColor,
    required this.punchIconType,
    required this.category,
  });
  final String businessName, programName, rewardName, punchTerm;
  final int punchesRequired, signupBonus;
  final String primaryColor, backgroundColor, textColor, punchColor, punchIconType, category;
}

class OwnerRepository {
  OwnerRepository(this._client);
  final SupabaseClient _client;

  /// Creates business → program → reward. RLS guarantees rows belong to the caller.
  Future<void> createBusinessWithProgram(NewProgramInput i) async {
    final uid = _client.auth.currentUser!.id;
    final business = await _client.from('businesses')
        .insert({
          'owner_id': uid,
          'name': i.businessName,
          'slug': slugify(i.businessName),
          'category': i.category,
        })
        .select().single();
    final program = await _client.from('loyalty_programs').insert({
      'business_id': business['id'],
      'name': i.programName,
      'slug': slugify(i.programName),
      'status': 'active',
      'punches_required': i.punchesRequired,
      'punch_term': i.punchTerm,
      'signup_bonus': i.signupBonus,
      'primary_color': i.primaryColor,
      'background_color': i.backgroundColor,
      'text_color': i.textColor,
      'punch_color': i.punchColor,
      'punch_icon_type': i.punchIconType,
    }).select().single();
    await _client.from('program_rewards').insert({
      'business_id': business['id'],
      'program_id': program['id'],
      'name': i.rewardName,
      'punch_threshold': i.punchesRequired,
    });
  }
}

final ownerRepositoryProvider = Provider((ref) => OwnerRepository(ref.watch(supabaseProvider)));
