import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/sync_scheduler.dart';
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

    return MaterialApp.router(
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      theme: ResTheme.light(),
      darkTheme: ResTheme.dark(),
      // Follows the OS. A manual override lands with the settings screen; the
      // token system already supports both directions.
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
