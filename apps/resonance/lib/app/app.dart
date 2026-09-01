import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/sync_scheduler.dart';
import '../core/telemetry/local_funnel.dart';
import '../core/telemetry/telemetry_settings.dart';
import '../features/settings/telemetry_notice.dart';
import '../ui/tokens/theme.dart';
import 'router.dart';

class ResonanceApp extends ConsumerWidget {
  const ResonanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing reads the result. Watching it is what keeps the outbox
    // draining for the life of the app; without a watcher the provider is
    // never constructed and the queue silently never leaves the device.
    ref.watch(syncSchedulerProvider);
    // Same reason: unwatched, the recorder is never constructed and the one
    // product signal worth having is silently never written down.
    ref.watch(funnelRecorderProvider);

    final telemetry = ref.watch(telemetrySettingsProvider);

    // On a test build the notice stands in front of the app until it is
    // dismissed. It gates the UI *and* `maySend` gates the reporter, so a
    // crash before the notice is acknowledged is dropped rather than queued —
    // "we told the testers" has to be something you can point at.
    //
    // Done through `builder` rather than by swapping the router out, so the
    // route stack underneath is untouched and the app resumes exactly where it
    // was once the notice is answered.
    final owesNotice =
        TelemetrySettings.isInternalBuild && !telemetry.noticeSeen;

    return MaterialApp.router(
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      theme: ResTheme.light(),
      darkTheme: ResTheme.dark(),
      // Follows the OS. A manual override lands with the settings screen; the
      // token system already supports both directions.
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          owesNotice ? const TelemetryNotice() : (child ?? const SizedBox()),
    );
  }
}
