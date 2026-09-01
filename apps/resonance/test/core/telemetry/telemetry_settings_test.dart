import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/telemetry/crash_reporter.dart';
import 'package:resonance/core/telemetry/telemetry_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('consent', () {
    test('enabled without the notice seen does not permit sending', () {
      // The tester default. On, but nobody has been told yet — and a notice
      // nobody has seen is not a notice.
      const settings = TelemetrySettings(enabled: true, noticeSeen: false);
      expect(settings.maySend, isFalse);
    });

    test('the notice seen without consent does not permit sending', () {
      const settings = TelemetrySettings(enabled: false, noticeSeen: true);
      expect(settings.maySend, isFalse);
    });

    test('sending needs both consent and having been informed', () {
      const settings = TelemetrySettings(enabled: true, noticeSeen: true);
      expect(settings.maySend, isTrue);
    });
  });

  group('persistence', () {
    test('a store build defaults to off', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = await TelemetrySettings.load(prefs);

      // The test binary is not built with RESONANCE_INTERNAL_BUILD.
      expect(TelemetrySettings.isInternalBuild, isFalse);
      expect(settings.enabled, isFalse);
      expect(settings.noticeSeen, isFalse);
      expect(
        settings.maySend,
        isFalse,
        reason: 'a store build must collect nothing until asked',
      );
    });

    test('a choice survives a restart', () async {
      final prefs = await SharedPreferences.getInstance();
      await const TelemetrySettings(
        enabled: true,
        noticeSeen: true,
      ).save(prefs);

      final reloaded = await TelemetrySettings.load(prefs);
      expect(reloaded.maySend, isTrue);

      await const TelemetrySettings(
        enabled: false,
        noticeSeen: true,
      ).save(prefs);
      expect((await TelemetrySettings.load(prefs)).maySend, isFalse);
    });
  });

  group('the reporter', () {
    test('an unconfigured build never starts the SDK', () async {
      final reporter = CrashReporter(dsn: '');
      expect(reporter.isConfigured, isFalse);

      var ran = false;
      await reporter.start(maySend: () => true, runApp: () => ran = true);

      expect(ran, isTrue, reason: 'the app must still launch');
      expect(
        reporter.isRunning,
        isFalse,
        reason: 'no DSN means no SDK, not a silently half-started one',
      );
    });

    test('reporting through an inactive reporter is a no-op, not a crash', () {
      final reporter = CrashReporter(dsn: '');
      expect(
        () => reporter.report(StateError('boom'), StackTrace.current),
        returnsNormally,
      );
    });
  });
}
