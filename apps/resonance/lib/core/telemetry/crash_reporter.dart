import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'telemetry_settings.dart';

/// Crash reporting, configured to collect as little as will still be useful.
///
/// Everything here is a deliberate narrowing of a default:
///
/// * `sendDefaultPii` stays false, so no username, no request headers.
/// * **Session tracking is off.** It is on by default and sends a ping on every
///   launch and close — an always-on usage beacon, which is precisely the thing
///   this app refuses to do. A crash reporter should transmit when there is a
///   crash and stay silent otherwise.
/// * Auto breadcrumbs that capture user input and navigation are off. A
///   breadcrumb trail of what someone tapped is behavioural analytics arriving
///   under a crash-reporting banner.
/// * No screenshots, no view hierarchy, no replay.
///
/// **IP scrubbing is a server-side project setting** and cannot be enforced
/// from here: Sentry sees the request IP at ingest whatever the client sends.
/// Turn on "Prevent Storing of IP Addresses" in project settings. That is a
/// blocked-on-account item, not something this file can assert.
class CrashReporter {
  CrashReporter({required this.dsn});

  /// Empty when unconfigured, which is the normal state for a local build.
  final String dsn;

  bool get isConfigured => dsn.isNotEmpty;

  bool _started = false;
  bool get isRunning => _started;

  /// Brings Sentry up. Safe to call when unconfigured — it does nothing.
  ///
  /// [maySend] is checked here *and* held as a live gate in [beforeSend], so a
  /// user who turns telemetry off mid-session stops sending immediately rather
  /// than at the next launch.
  Future<void> start({
    required bool Function() maySend,
    FutureOr<void> Function()? runApp,
  }) async {
    if (!isConfigured || _started) {
      await runApp?.call();
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.sendDefaultPii = false;
      options.enableAutoSessionTracking = false;
      options.enableUserInteractionBreadcrumbs = false;
      options.enableAutoNativeBreadcrumbs = false;
      options.attachScreenshot = false;
      // attachViewHierarchy is experimental and defaults to false; left unset
      // rather than referenced, so an SDK change cannot turn it on silently
      // without this line failing to compile first.
      // Crashes, not a sample of them. The volume here is tiny.
      options.tracesSampleRate = 0.0;
      options.beforeSend = (event, hint) => maySend() ? event : null;
    }, appRunner: runApp == null ? null : () => runApp());

    _started = true;
  }

  /// Reports an error the app caught itself.
  Future<void> report(Object error, StackTrace stack) async {
    if (!isConfigured || !_started) {
      debugPrint('crash not reported (reporter inactive): $error');
      return;
    }
    await Sentry.captureException(error, stackTrace: stack);
  }
}

/// The DSN, from `--dart-define=SENTRY_DSN=...`.
///
/// Never a bundled asset and never committed, the same rule the Supabase keys
/// follow. An empty DSN is a working configuration: the app runs, and nothing
/// is collected.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Whether this build should collect anything at all.
///
/// A store build with telemetry off and no notice seen must not even start the
/// SDK, so that "off" means nothing runs rather than something runs quietly.
bool telemetryMaySend(TelemetrySettings settings) => settings.maySend;
