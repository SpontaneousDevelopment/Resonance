import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User control over when syncing happens.
///
/// **Deliberately about progress data only.** Attempts, mastery and streaks are
/// a few hundred bytes each; syncing them on cellular costs nothing worth a
/// setting, which is why this defaults on.
///
/// Audio is a different question entirely, and this setting must never come to
/// govern it. If uploading recordings ever ships it needs its own control with
/// its own default — a user who left "sync on cellular" on because it was
/// cheap should not discover they have been uploading audio over it. The two
/// are separated here before there is any pressure to conflate them.
class SyncSettings {
  const SyncSettings({this.syncOnCellular = true});

  /// Whether progress data may sync over a metered connection.
  ///
  /// Governs progress only. See the class comment.
  final bool syncOnCellular;

  static const _key = 'sync_on_cellular';

  static Future<SyncSettings> load(SharedPreferences prefs) async =>
      SyncSettings(syncOnCellular: prefs.getBool(_key) ?? true);

  Future<void> save(SharedPreferences prefs) =>
      prefs.setBool(_key, syncOnCellular);

  SyncSettings copyWith({bool? syncOnCellular}) =>
      SyncSettings(syncOnCellular: syncOnCellular ?? this.syncOnCellular);
}

class SyncSettingsNotifier extends Notifier<SyncSettings> {
  @override
  SyncSettings build() {
    // Defaults on, then corrected from storage a frame later. Progress data is
    // small enough that defaulting off would cost users a stale account for no
    // benefit they asked for.
    _restore();
    return const SyncSettings();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = await SyncSettings.load(prefs);
  }

  Future<void> setSyncOnCellular(bool value) async {
    state = state.copyWith(syncOnCellular: value);
    await state.save(await SharedPreferences.getInstance());
  }
}

final syncSettingsProvider =
    NotifierProvider<SyncSettingsNotifier, SyncSettings>(
      SyncSettingsNotifier.new,
    );
