import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../ui/core/error_view.dart';
import '../../../ui/core/public_card_frame.dart';
import '../../../ui/core/punch_row.dart';

/// /c/:token — the customer's whole experience. The token in the URL is the only credential.
class CardScreen extends StatefulWidget {
  const CardScreen({super.key, required this.token, this.justJoined = false});
  final String token;
  final bool justJoined;

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  Map<String, dynamic>? _card;
  String? _error;
  RealtimeChannel? _channel;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    // The scan QR expires after 60s; renew it (and heal any missed realtime message).
    _refresh = Timer.periodic(const Duration(seconds: 45), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final card = await callRpcMap('get_public_card_client', {
        'p_token': widget.token,
      });
      final scan = card['scan'] as Map?;
      if (scan != null) {
        card['scan_code'] = mintScanCode(
          scan['scan_id'] as String,
          scan['scan_secret_hex'] as String,
        );
        card.remove('scan');
      }
      if (!mounted) return;
      setState(() {
        _card = card;
        _error = null;
      });
      _subscribe(card['realtime_channel'] as String);
    } on AppException catch (e) {
      if (mounted && _card == null) setState(() => _error = e.message);
    }
  }

  void _subscribe(String channelId) {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel('card:$channelId')
        .onBroadcast(event: 'changed', callback: (_) => _load())
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: ErrorView(_error!, onRetry: _load));
    }
    final c = _card;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = c['program'] as Map, b = c['business'] as Map;
    final bg = parseHex(p['background_color'], Colors.white);
    final fg = parseHex(p['text_color'], Colors.black87);
    final accent = parseHex(p['punch_color'] ?? p['primary_color'], AppTheme.seed);
    final total = p['punches_required'] as int;
    final current = c['current_punches'] as int;
    final tiers = p['reward_mode'] == 'tiers';
    final rewards = (c['available_rewards'] as List).cast<Map>();
    final activity = (c['activity'] as List).cast<Map>();
    final term = p['punch_term'] as String;
    final scanCode = c['scan_code'] as String?;
    final punchIcon = p['punch_icon_type'] as String?;
    final coverImage = p['cover_image_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      body: RefreshIndicator(
        onRefresh: _load,
        child: PublicCardFrame(
          background: bg,
          accent: accent,
          coverImageUrl: coverImage,
          child: Column(children: [
            Text(b['name'], textAlign: TextAlign.center, style: TextStyle(color: fg.withValues(alpha: 0.7), letterSpacing: 1.1, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(p['name'], textAlign: TextAlign.center,
                style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w700)),
            if (widget.justJoined) ...[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                color: AppColors.greenSurface,
                textColor: AppColors.green,
                icon: Icons.celebration_outlined,
                text: 'Your card is ready. Save this page to your home screen!',
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (!tiers) PunchRow(total: total, filled: current, color: accent, iconType: punchIcon),
            const SizedBox(height: AppSpacing.lg),
            Text(tiers ? '$current ${term}s' : '$current / $total ${term}s',
                textAlign: TextAlign.center,
                style: TextStyle(color: fg, fontSize: 19, fontWeight: FontWeight.w700)),
            if (!tiers) Text(
              '${total - current} more until your reward.',
              textAlign: TextAlign.center, style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 12.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (c['blocked'] == true)
              _Banner(
                color: AppColors.errorSurface,
                textColor: AppColors.error,
                icon: Icons.block,
                text: 'This card is disabled. Please talk to the business.',
              )
            else if (scanCode != null) Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: fg.withValues(alpha: 0.08)),
                ),
                child: QrImageView(data: scanCode, size: 200),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Show this QR when you make a purchase.',
                textAlign: TextAlign.center, style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 12)),
            const SizedBox(height: AppSpacing.xl),
            Align(alignment: Alignment.centerLeft,
                child: Text('Available rewards', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(height: AppSpacing.sm),
            if (rewards.isEmpty)
              Text('No rewards available yet.', style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 13))
            else
              for (final r in rewards)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(children: [
                    Icon(Icons.redeem, color: accent, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r['name'], style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13.5)),
                        Text(
                          r['expires_at'] == null
                              ? 'Available to redeem'
                              : 'Expires ${DateFormat.MMMd().format(DateTime.parse(r['expires_at']).toLocal())}',
                          style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11.5),
                        ),
                      ]),
                    ),
                  ]),
                ),
            const SizedBox(height: AppSpacing.lg),
            Align(alignment: Alignment.centerLeft,
                child: Text('Recent activity', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14))),
            const SizedBox(height: AppSpacing.sm),
            if (activity.isEmpty) Align(alignment: Alignment.centerLeft,
                child: Text('Nothing yet.', style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 13))),
            for (final a in activity)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(_label(a, term), style: TextStyle(color: fg, fontSize: 13))),
                  Text(DateFormat.MMMd().format(DateTime.parse(a['created_at']).toLocal()),
                      style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 12)),
                ]),
              ),
            if (c['show_branding'] == true) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Powered by PunchCardQR', textAlign: TextAlign.center,
                  style: TextStyle(color: fg.withValues(alpha: 0.35), fontSize: 11)),
            ],
          ]),
        ),
      ),
    );
  }

  String _label(Map a, String term) {
    final q = a['quantity'] as int;
    switch (a['event_type']) {
      case 'punch_added':
      case 'promotion_bonus':
      case 'manual_adjustment':
        return '+$q $term';
      case 'signup_bonus':
        return '+$q welcome $term';
      case 'punch_reversed':
        return '$q $term (corrected)';
      case 'reward_earned':
        return 'Reward unlocked';
      case 'reward_redeemed':
        return 'Reward redeemed';
      default:
        return '${a['event_type']}';
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.textColor, required this.icon, required this.text});
  final Color color, textColor;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        child: Row(children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: TextStyle(color: textColor, fontSize: 12.5))),
        ]),
      );
}
