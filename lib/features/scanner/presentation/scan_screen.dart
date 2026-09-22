import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/ids.dart';
import '../../../ui/core/punch_row.dart';
import '../../business/data/owner_repository.dart';
import '../../locations/data/locations_repository.dart';

/// Punch Mode: scan → customer → confirm → punch / redeem / undo.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  Map<String, dynamic>? _customer;
  bool _resolving = false;
  String? _message;
  bool _messageIsError = false;

  String? _locationId;
  bool _locationResolved = false;
  bool _resolvingLocation = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String m, {bool error = false}) => setState(() {
    _message = m;
    _messageIsError = error;
  });

  Future<void> _resolveLocation(String businessId, List<Map<String, dynamic>> locations) async {
    if (_resolvingLocation) return;
    _resolvingLocation = true;
    if (locations.length <= 1) {
      final id = locations.isEmpty ? null : locations.first['id'] as String;
      if (mounted) setState(() { _locationId = id; _locationResolved = true; });
      return;
    }
    final saved = await ScanLocationPrefs.get(businessId);
    final valid = saved != null && locations.any((l) => l['id'] == saved);
    if (mounted) setState(() { _locationId = valid ? saved : null; _locationResolved = true; });
  }

  Future<void> _pickLocation(String businessId, Map<String, dynamic> location) async {
    await ScanLocationPrefs.set(businessId, location['id'] as String);
    setState(() => _locationId = location['id'] as String);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_resolving || _customer != null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    setState(() {
      _resolving = true;
      _message = null;
    });
    try {
      final c = await callRpcMap('resolve_scan_client', {'p_scan_code': code});
      setState(() => _customer = c);
    } on AppException catch (e) {
      _say(e.message, error: true);
      await Future<void>.delayed(
        const Duration(seconds: 2),
      ); // let the cashier read the error
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _reset() => setState(() {
    _customer = null;
    _message = null;
  });

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(ownerContextProvider).value?.program;
    if (program != null && program['status'] != 'active') {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('Your program is paused. Activate it to scan customers.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final business = ref.watch(ownerContextProvider).value?.business;
    final locations = ref.watch(activeLocationsProvider).value;
    if (business != null && locations != null && !_locationResolved) {
      _resolveLocation(business['id'] as String, locations);
    }

    if (business != null && locations != null && locations.length > 1 && _locationId == null) {
      return _LocationPicker(locations: locations, onPick: (l) => _pickLocation(business['id'] as String, l));
    }

    final currentLocationName = locations?.firstWhere(
      (l) => l['id'] == _locationId,
      orElse: () => const {},
    )['name'] as String?;

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(
        title: const Text('Scan customer'),
        actions: [
          if (currentLocationName != null && (locations?.length ?? 0) > 1)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _locationId = null),
                  icon: const Icon(Icons.storefront_outlined, size: 16),
                  label: Text(currentLocationName, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
        ],
      ),
      body: _customer == null
          ? Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: AppColors.navy.withValues(alpha: 0.85),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      _message ??
                          (_resolving
                              ? 'Reading…'
                              : 'Point the camera at the customer\'s QR'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _messageIsError ? const Color(0xFFFF8A80) : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _CustomerPanel(customer: _customer!, locationId: _locationId, onDone: _reset),
    );
  }
}

class _LocationPicker extends StatelessWidget {
  const _LocationPicker({required this.locations, required this.onPick});
  final List<Map<String, dynamic>> locations;
  final ValueChanged<Map<String, dynamic>> onPick;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.neutral0,
        appBar: AppBar(title: const Text('Choose a location')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Which location is this device at?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Punches and redemptions will be attributed to this location. You can change it anytime from the Scan screen.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            for (final l in locations)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => onPick(l),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.storefront, color: AppColors.blue),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            if ((l['city'] as String?)?.isNotEmpty ?? false)
                              Text(l['city'], style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.neutral400),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

class _CustomerPanel extends StatefulWidget {
  const _CustomerPanel({required this.customer, required this.onDone, this.locationId});
  final Map<String, dynamic> customer;
  final String? locationId;
  final VoidCallback onDone;
  @override
  State<_CustomerPanel> createState() => _CustomerPanelState();
}

class _CustomerPanelState extends State<_CustomerPanel> {
  late Map<String, dynamic> _state = Map<String, dynamic>.from(
    widget.customer['state'] as Map,
  );
  late final List<Map<String, dynamic>> _rewards =
      (widget.customer['available_rewards'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
  bool _busy = false;
  String? _message;
  bool _isError = false;
  // Kept until the action succeeds, so a retry after a network hiccup can't double-punch.
  String? _pendingKey;

  String get _membershipId => widget.customer['membership_id'] as String;

  Future<void> _run(Future<void> Function(String key) action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    _pendingKey ??= newIdempotencyKey();
    try {
      await action(_pendingKey!);
      _pendingKey = null;
    } on AppException catch (e) {
      _pendingKey =
          null; // a definitive server answer; next tap is a new intent
      final since = e.data['seconds_since_last'];
      setState(() {
        _message = since != null
            ? 'Punch recently added. Last punch: ${since}s ago.'
            : e.message;
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _punch() async {
    if (!await _confirm(
      'Add punch?',
      'Add 1 to ${widget.customer['display_name']}.',
    )) {
      return;
    }
    await _run((key) async {
      final r = await callRpcMap('award_punch_client', {
        'p_membership': _membershipId,
        'p_idem': key,
        'p_location': widget.locationId,
      });
      final earned = (r['rewards_earned'] ?? 0) as int;
      setState(() {
        _state = Map<String, dynamic>.from(r['state'] as Map);
        _isError = false;
        _message = earned > 0
            ? '🎉 Reward unlocked! Scan the card again to redeem it.'
            : 'Punch added · ${_state['current_punches']} / ${_state['punches_required']}';
      });
    });
  }

  Future<void> _redeem(Map<String, dynamic> r) async {
    if (!await _confirm(
      'Redeem ${r['name']}?',
      'This action will be recorded.',
    )) {
      return;
    }
    await _run((key) async {
      final res = await callRpcMap('redeem_reward_client', {
        'p_earned_reward': r['earned_reward_id'],
        'p_idem': key,
        'p_location': widget.locationId,
      });
      setState(() {
        _state = Map<String, dynamic>.from(res['state'] as Map);
        _rewards.remove(r);
        _isError = false;
        _message = 'Reward redeemed successfully.';
      });
    });
  }

  Future<void> _undo() async {
    if (!await _confirm(
      'Undo last punch?',
      'This reverses the most recent punch.',
    )) {
      return;
    }
    await _run((key) async {
      final res = await callRpcMap('reverse_last_punch_client', {
        'p_membership': _membershipId,
        'p_idem': key,
      });
      setState(() {
        _state = Map<String, dynamic>.from(res['state'] as Map);
        _isError = false;
        _message = 'Last punch undone.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tiers = _state['reward_mode'] == 'tiers';
    final total = _state['punches_required'] as int;
    final current = _state['current_punches'] as int;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Column(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.blueSurface,
                  child: Text(
                    (widget.customer['display_name'] as String).isNotEmpty
                        ? (widget.customer['display_name'] as String)[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: AppColors.blueDark, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.customer['display_name'],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(widget.customer['program_name'], style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                if (!tiers)
                  PunchRow(total: total, filled: current, color: AppColors.blue),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tiers ? '$current' : '$current / $total',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.customer['status'] != 'active')
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      'This card is disabled.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _isError ? AppColors.errorSurface : AppColors.greenSurface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isError ? AppColors.error : AppColors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _busy || widget.customer['status'] != 'active'
                  ? null
                  : _punch,
              icon: const Icon(Icons.add),
              label: const Text('Add punch'),
            ),
            for (final r in _rewards) ...[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _redeem(r),
                icon: const Icon(Icons.card_giftcard),
                label: Text('Redeem ${r['name']}'),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : _undo,
              child: const Text('Undo last punch'),
            ),
            OutlinedButton(
              onPressed: widget.onDone,
              child: const Text('Scan next customer'),
            ),
          ],
        ),
      ),
    );
  }
}
