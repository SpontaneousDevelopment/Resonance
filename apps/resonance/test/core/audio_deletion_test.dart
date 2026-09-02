import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/db/database.dart';
import 'package:resonance/core/progress/audio_store.dart';

/// Delete-my-data has to remove the recordings, not just the rows.
///
/// It did not. The `audioPath` column has documented since M3 that "the file is
/// deleted when the attempt is", and nothing anywhere deleted a file — the
/// recordings survived on disk, which is the one place that promise had to
/// hold. Multi-take makes it worse: one attempt now leaves N files.
///
/// These run against **real files in a real temporary directory**. The failure
/// being guarded is on the filesystem, and a fake deleter could not have caught
/// the original bug — there was nothing to fake.
void main() {
  late ResonanceDatabase db;
  late Directory dir;

  setUp(() async {
    db = ResonanceDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('resonance_audio_test');
  });

  tearDown(() async {
    await db.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<File> recording(String name) async {
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(List.filled(64, 7));
    return file;
  }

  Future<void> attemptWithTakes(
    String id,
    String? attemptAudio,
    List<String?> takeAudio,
  ) async {
    await db.insertAttempt(
      AttemptsCompanion.insert(
        id: id,
        lessonId: 'lesson-1',
        recordedAt: DateTime(2026, 9, 2),
        durationMs: 4000,
        score: 70,
        audioPath: Value(attemptAudio),
      ),
    );
    for (var i = 0; i < takeAudio.length; i++) {
      await db.insertTakeRecord(
        TakeRecordsCompanion.insert(
          attemptId: id,
          takeIndex: i,
          label: 'Take ${i + 1}',
          durationMs: 1500,
          audioPath: Value(takeAudio[i]),
        ),
      );
    }
  }

  test('every take of a multi-take attempt is deleted', () async {
    final files = [
      await recording('take0.m4a'),
      await recording('take1.m4a'),
      await recording('take2.m4a'),
    ];
    await attemptWithTakes('a1', null, [for (final f in files) f.path]);

    expect(await AudioStore(db).deleteAll(), 3);
    for (final f in files) {
      expect(
        f.existsSync(),
        isFalse,
        reason: '${f.path} survived delete-my-data',
      );
    }
  });

  test('single-take attempts are deleted too', () async {
    // N=1 is the same path, and it is the one that has been broken all along.
    final file = await recording('single.m4a');
    await attemptWithTakes('a2', file.path, const []);

    expect(await AudioStore(db).deleteAll(), 1);
    expect(file.existsSync(), isFalse);
  });

  test('files across several attempts all go', () async {
    final a = await recording('a.m4a');
    final b = await recording('b.m4a');
    final c = await recording('c.m4a');
    await attemptWithTakes('a3', a.path, [b.path]);
    await attemptWithTakes('a4', null, [c.path]);

    expect(await AudioStore(db).deleteAll(), 3);
    expect(dir.listSync(), isEmpty);
  });

  test('a missing file does not stop the rest', () async {
    final present = await recording('present.m4a');
    await attemptWithTakes('a5', '${dir.path}/never_existed.m4a', [
      present.path,
    ]);

    expect(await AudioStore(db).deleteAll(), 1);
    expect(present.existsSync(), isFalse);
  });

  test('a take with no recorded file is skipped, not an error', () async {
    final present = await recording('kept.m4a');
    await attemptWithTakes('a6', null, [null, present.path]);

    expect(await AudioStore(db).deleteAll(), 1);
    expect(present.existsSync(), isFalse);
  });

  test('wiping the rows first would strand the files', () async {
    // Why AccountService deletes files before rows: the rows are the only
    // record of where the files are.
    final file = await recording('orphan.m4a');
    await attemptWithTakes('a7', null, [file.path]);

    await db.deleteAllUserData();

    expect(await db.allAudioPaths(), isEmpty);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'still on disk with nothing pointing at it — undeletable by the app, '
          'which is exactly the order bug this guards',
    );
    await file.delete();
  });
}
