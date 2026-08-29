import 'package:flutter/material.dart';

import '../ui/tokens/theme.dart';
import 'router.dart';

class ResonanceApp extends StatelessWidget {
  const ResonanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      theme: ResTheme.light(),
      darkTheme: ResTheme.dark(),
      // Follows the OS. A manual override lands with the settings screen; the
      // token system already supports both directions.
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
