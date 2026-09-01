import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether crash reports may leave the device, and whether the user has been
/// told they can.
///
/// **Deliberately not tied to sign-in.** Signing in means sync and nothing
/// else; if it also switched telemetry on, it would quietly mean two things,
/// and a user who wanted their progress on a second device would have agreed to
/// something they were never asked about.
///
/// Two different defaults, because the populations are different:
///
/// * **Internal and TestFlight builds** default to on. A tester has agreed to
///   test. But they still see [TelemetryNotice] before anything is sent — a
///   notice nobody has to acknowledge is not a notice.
/// * **Store builds** default to off and are asked once, in settings. Nothing
///   is collected until someone says yes.
///
/// The build type is set at compile time so this cannot drift: a store build
/// physically cannot ship with the tester default.
class TelemetrySettings {
  const TelemetrySettings({required this.enabled, required this.noticeSeen});

  /// Whether crash reports may be sent.
  final bool enabled;

  /// Whether the user has actually been shown what is collected.
  ///
  /// Separate from [enabled] on purpose. On a tester build the default is on,
  /// but "on" without "seen" must not send anything.
  final bool noticeSeen;

  /// True when reports may actually go out — consented *and* informed.
  bool get maySend => enabled && noticeSeen;

  /// Whether this build defaults telemetry on and owes the user a notice.
  ///
  /// Set with `--dart-define=RESONANCE_INTERNAL_BUILD=true`, which release
  /// tooling passes and a store build does not.
  static const isInternalBuild = bool.fromEnvironment(
    'RESONANCE_INTERNAL_BUILD',
  );

  static const _enabledKey = 'telemetry_enabled';
  static const _noticeKey = 'telemetry_notice_seen';

  static Future<TelemetrySettings> load(SharedPreferences prefs) async =>
      TelemetrySettings(
        enabled: prefs.getBool(_enabledKey) ?? isInternalBuild,
        noticeSeen: prefs.getBool(_noticeKey) ?? false,
      );

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setBool(_noticeKey, noticeSeen);
  }

  TelemetrySettings copyWith({bool? enabled, bool? noticeSeen}) =>
      TelemetrySettings(
        enabled: enabled ?? this.enabled,
        noticeSeen: noticeSeen ?? this.noticeSeen,
      );
}

class TelemetrySettingsNotifier extends Notifier<TelemetrySettings> {
  @override
  TelemetrySettings build() {
    _restore();
    // Never `maySend` until storage has been read: the safe direction is to
    // send nothing while we do not yet know what the user chose.
    return TelemetrySettings(
      enabled: TelemetrySettings.isInternalBuild,
      noticeSeen: false,
    );
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = await TelemetrySettings.load(prefs);
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await state.save(await SharedPreferences.getInstance());
    debugPrint('telemetry ${value ? 'enabled' : 'disabled'} by the user');
  }

  /// Called when the notice has actually been put in front of someone.
  Future<void> acknowledgeNotice({required bool enabled}) async {
    state = state.copyWith(noticeSeen: true, enabled: enabled);
    await state.save(await SharedPreferences.getInstance());
  }
}

final telemetrySettingsProvider =
    NotifierProvider<TelemetrySettingsNotifier, TelemetrySettings>(
      TelemetrySettingsNotifier.new,
    );
