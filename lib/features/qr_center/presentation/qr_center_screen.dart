import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageByteFormat, PictureRecorder;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../ui/core/app_card.dart';
import '../../business/data/owner_repository.dart';

class QrCenterScreen extends ConsumerWidget {
  const QrCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(ownerContextProvider).value;
    final program = ctx?.program;
    if (program == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final url = '${Env.appUrl}/j/${program['slug']}';

    Future<void> download() async {
      // Render on a white canvas so the PNG prints correctly (QrPainter alone is transparent).
      const size = 1024.0, margin = 64.0;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, size + margin * 2, size + margin * 2), Paint()..color = Colors.white);
      canvas.translate(margin, margin);
      QrPainter(data: url, version: QrVersions.auto, gapless: true).paint(canvas, const Size(size, size));
      final image = await recorder.endRecording().toImage((size + margin * 2).toInt(), (size + margin * 2).toInt());
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      await FileSaver.instance.saveFile(
        name: 'join-${program['slug']}', bytes: bytes!.buffer.asUint8List(), fileExtension: 'png', mimeType: MimeType.png);
    }

    return Scaffold(
      backgroundColor: AppColors.neutral0,
      appBar: AppBar(title: const Text('QR codes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [
            Text('Join ${program['name']}', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text('Customers scan this to get their card. No app, no account.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: QrImageView(data: url, size: 220, backgroundColor: Colors.white),
                ),
                const SizedBox(height: AppSpacing.md),
                SelectableText(url, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(onPressed: download, icon: const Icon(Icons.download), label: const Text('Download PNG')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Copy link'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                }
              },
            ),
          ]),
        ),
      ),
    );
  }
}
