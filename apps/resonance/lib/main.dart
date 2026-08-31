import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/net/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Anonymous-first: this returns false when no backend is configured, and the
  // app runs exactly as it always has. Sign-in is additive, never a gate.
  await initialiseSupabase();

  runApp(const ProviderScope(child: ResonanceApp()));
}
