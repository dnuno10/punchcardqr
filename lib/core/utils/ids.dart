import 'dart:math';

final _rng = Random.secure();

/// One key per user action; reused on retries so the server never applies it twice.
String newIdempotencyKey() =>
    List.generate(16, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

/// `Coffee House!` → `coffee-house-x7k2` (random suffix keeps public slugs unique and unguessable-ish).
String slugify(String name) {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final suffix = List.generate(4, (_) => chars[_rng.nextInt(chars.length)]).join();
  final base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return '${base.isEmpty ? 'shop' : base}-$suffix';
}
