import 'package:flutter/services.dart';

/// Keeps the app window on screen for the duration of an integration test.
///
/// Not a convenience. `tester.pump()` waits for a frame from the window's
/// display link, and macOS pauses that display link while the window is fully
/// occluded — so a run behind a maximised editor stalls rather than fails, for
/// as long as it stays covered. See `MainFlutterWindow.swift` for the full
/// account; the short version is that a test which cannot see its own window
/// cannot pump, and a stall is worse than a failure because there is nothing to
/// point at.
///
/// Silently does nothing where the channel is not registered — release builds,
/// and every platform but macOS — so the same tests run unchanged elsewhere.
Future<void> keepTestWindowOnScreen() async {
  try {
    await const MethodChannel(
      'app.resonance/test_window',
    ).invokeMethod<void>('keepOnScreen');
  } on MissingPluginException {
    // Nothing is listening. That is a normal state, not a failure.
  }
}
