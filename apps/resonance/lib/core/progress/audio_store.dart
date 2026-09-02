import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';

/// Deletes the recordings a user's attempts point at.
///
/// This exists because deleting the rows was never deleting the audio. The
/// `audioPath` column has always documented that "the file is deleted when the
/// attempt is" and nothing anywhere did it — the recordings survived
/// delete-my-data on disk, which is the one place the promise had to hold.
///
/// Now doubly load-bearing: a multi-take lesson writes one file per take, so a
/// single attempt can leave three behind rather than one.
///
/// Separate from the database because a `Database` reaching into the filesystem
/// is how you end up unable to test either.
class AudioStore {
  const AudioStore(this._db, {FileSystemDeleter? deleter})
    : _delete = deleter ?? _realDelete;

  final ResonanceDatabase _db;
  final FileSystemDeleter _delete;

  static Future<bool> _realDelete(String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  }

  /// Removes every recording this device holds, across attempts and takes.
  ///
  /// Returns how many files were actually removed. Failures on individual files
  /// are swallowed on purpose: a file already gone, or on a volume that has
  /// disappeared, must not stop the rest of a deletion the user asked for.
  Future<int> deleteAll() async {
    var removed = 0;
    for (final path in await _db.allAudioPaths()) {
      try {
        if (await _delete(path)) removed++;
      } catch (error) {
        debugPrint('could not delete recording $path: $error');
      }
    }
    return removed;
  }
}

/// Injectable so deletion can be asserted without a real filesystem — and, more
/// to the point, so a test can prove the *paths* reaching it are all of them.
typedef FileSystemDeleter = Future<bool> Function(String path);

final audioStoreProvider = Provider<AudioStore>(
  (ref) => AudioStore(ref.watch(databaseProvider)),
);
