import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  usePathUrlStrategy(); // /c/{token}, not /#/c/{token}
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.isConfigured) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Missing SUPABASE_URL / SUPABASE_ANON_KEY.\n'
                'Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...'),
          ),
        ),
      ),
    ));
    return;
  }
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  runApp(const ProviderScope(child: PunchCardApp()));
}
