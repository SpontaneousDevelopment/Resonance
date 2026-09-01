import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/net/supabase_bootstrap.dart';
import 'core/telemetry/crash_reporter.dart';
import 'core/telemetry/telemetry_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Anonymous-first: this returns false when no backend is configured, and the
  // app runs exactly as it always has. Sign-in is additive, never a gate.
  await initialiseSupabase();

  // The container is built here rather than inside `runApp` so the reporter can
  // ask it, on every event, whether sending is still allowed. Turning telemetry
  // off in settings therefore stops the next report, not the next launch.
  final container = ProviderContainer();
  final reporter = CrashReporter(dsn: sentryDsn);

  await reporter.start(
    maySend: () => container.read(telemetrySettingsProvider).maySend,
    runApp: () => runApp(
      UncontrolledProviderScope(
        container: container,
        child: const ResonanceApp(),
      ),
    ),
  );
}
