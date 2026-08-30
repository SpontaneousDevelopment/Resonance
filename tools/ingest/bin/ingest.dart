// Licence-checked ingestion of reference audio.
//
// Nothing is downloaded until the source has positively stated a licence that
// permits redistribution. The check fails closed: an unreachable API, an
// unreadable response, or a licence not on the allow list all refuse.
//
//   dart run tools/ingest/bin/ingest.dart add --youtube <id>  --as <local-id>
//   dart run tools/ingest/bin/ingest.dart add --archive <id>  --as <local-id>
//   dart run tools/ingest/bin/ingest.dart verify     # offline: files vs manifest
//   dart run tools/ingest/bin/ingest.dart restore    # re-fetch from manifest
//   dart run tools/ingest/bin/ingest.dart audit      # re-check licences upstream

import 'dart:io';

import 'package:ingest/licence.dart';
import 'package:ingest/manifest.dart';
import 'package:ingest/sources.dart';
import 'package:path/path.dart' as p;

const audioDir = 'apps/resonance/assets/audio';

Future<int> main(List<String> args) async {
  if (args.isEmpty) {
    _usage();
    return 1;
  }

  final root = _repoRoot();
  return switch (args.first) {
    'add' => await _add(root, args.skip(1).toList()),
    'verify' => _verify(root),
    'restore' => await _restore(root),
    'audit' => await _audit(root),
    _ => () {
      _usage();
      return 1;
    }(),
  };
}

Future<int> _add(String root, List<String> args) async {
  final options = _parse(args);
  final localId = options['as'];
  if (localId == null) {
    stderr.writeln('error: --as <local-id> is required');
    return 1;
  }

  final youtubeId = options['youtube'];
  final archiveId = options['archive'];
  if ((youtubeId == null) == (archiveId == null)) {
    stderr.writeln('error: pass exactly one of --youtube or --archive');
    return 1;
  }

  final approvedBy = options['approved-by'] ?? Platform.environment['USER'];
  if (approvedBy == null || approvedBy.isEmpty) {
    stderr.writeln('error: --approved-by is required');
    stderr.writeln('       A licence check says a clip *may* be used. Whether');
    stderr.writeln(
      '       it *should* be is a human call, and it is recorded.',
    );
    return 1;
  }

  stdout.writeln('Checking licence…');
  final LicenceVerdict verdict;
  final String sourceName;
  final String sourceId;

  if (youtubeId != null) {
    final key = Platform.environment['YOUTUBE_API_KEY'];
    if (key == null || key.isEmpty) {
      stderr.writeln('error: YOUTUBE_API_KEY is not set.');
      stderr.writeln('       The Data API is the only authoritative statement');
      stderr.writeln(
        '       of a video\'s licence. A description saying "CC BY"',
      );
      stderr.writeln('       is not one, and yt-dlp will download either way.');
      return 1;
    }
    verdict = await YouTubeSource(apiKey: key).check(youtubeId);
    sourceName = 'youtube';
    sourceId = youtubeId;
  } else {
    verdict = await ArchiveSource().check(archiveId!);
    sourceName = 'archive';
    sourceId = archiveId;
  }

  if (!verdict.allowed) {
    stderr.writeln('REFUSED: ${verdict.reason}');
    stderr.writeln('Nothing was downloaded.');
    return 1;
  }

  stdout.writeln('  licence: ${verdict.licence}');
  stdout.writeln('  credit:  ${verdict.attribution}');

  final target = p.join(root, audioDir, '$localId.m4a');
  Directory(p.dirname(target)).createSync(recursive: true);

  stdout.writeln('Downloading…');
  final ok = await _download(
    source: sourceName,
    sourceId: sourceId,
    target: target,
  );
  if (!ok) return 1;

  final bytes = File(target).readAsBytesSync();
  final manifest = ReferenceManifest.load(root)
    ..add(
      ReferenceRecord(
        id: localId,
        source: sourceName,
        sourceId: sourceId,
        licence: verdict.licence,
        licenceUrl: verdict.licenceUrl!,
        attribution: verdict.attribution!,
        title: verdict.title!,
        assetPath: p.join(audioDir, '$localId.m4a'),
        sha256: hashOf(bytes),
        bytes: bytes.length,
        fetchedAt: DateTime.now().toUtc().toIso8601String(),
        approvedBy: approvedBy,
      ),
    );
  manifest.save(root);

  stdout.writeln('Added "$localId" (${bytes.length ~/ 1024} KB).');
  stdout.writeln('Reference it from curriculum YAML as:');
  stdout.writeln('  reference:');
  stdout.writeln(
    '    source: ${sourceName == 'archive' ? 'publicDomain' : 'creativeCommons'}',
  );
  stdout.writeln('    asset_path: ${p.join(audioDir, '$localId.m4a')}');
  stdout.writeln('    attribution: ${verdict.attribution}');
  stdout.writeln('    license_url: ${verdict.licenceUrl}');
  return 0;
}

Future<bool> _download({
  required String source,
  required String sourceId,
  required String target,
}) async {
  final url = source == 'youtube'
      ? 'https://www.youtube.com/watch?v=$sourceId'
      : 'https://archive.org/details/$sourceId';

  final result = await Process.run('yt-dlp', [
    '-x',
    '--audio-format',
    'm4a',
    '--no-playlist',
    '-o',
    target,
    url,
  ]);

  if (result.exitCode != 0) {
    stderr.writeln('Download failed:\n${result.stderr}');
    return false;
  }
  if (!File(target).existsSync()) {
    stderr.writeln('Download reported success but produced no file.');
    return false;
  }
  return true;
}

/// Offline: does what is on disk match what the manifest claims.
int _verify(String root) {
  final manifest = ReferenceManifest.load(root);
  if (manifest.records.isEmpty) {
    stdout.writeln('No references ingested yet.');
    return 0;
  }

  var problems = 0;
  for (final record in manifest.records) {
    final file = File(p.join(root, record.assetPath));
    if (!file.existsSync()) {
      stdout.writeln('MISSING  ${record.id} — run `restore`');
      problems++;
      continue;
    }
    final actual = hashOf(file.readAsBytesSync());
    if (actual != record.sha256) {
      stdout.writeln('CHANGED  ${record.id} — on-disk bytes differ');
      problems++;
      continue;
    }
    stdout.writeln('ok       ${record.id}  (${record.licence})');
  }

  stdout.writeln(
    problems == 0
        ? '\n${manifest.records.length} reference(s) verified.'
        : '\n$problems problem(s).',
  );
  return problems == 0 ? 0 : 1;
}

/// Re-fetches everything the manifest lists. This is what makes the gitignore's
/// claim that media is "reproducible from the manifests" actually true.
Future<int> _restore(String root) async {
  final manifest = ReferenceManifest.load(root);
  var failures = 0;

  for (final record in manifest.records) {
    final target = p.join(root, record.assetPath);
    if (File(target).existsSync()) {
      stdout.writeln('have     ${record.id}');
      continue;
    }
    stdout.writeln('fetching ${record.id}…');
    Directory(p.dirname(target)).createSync(recursive: true);
    final ok = await _download(
      source: record.source,
      sourceId: record.sourceId,
      target: target,
    );
    if (!ok) {
      failures++;
      continue;
    }
    // A source can be re-uploaded. Restoring different bytes than were
    // approved is worth knowing about rather than silently accepting.
    final actual = hashOf(File(target).readAsBytesSync());
    if (actual != record.sha256) {
      stdout.writeln(
        '  WARNING: bytes differ from what was approved — the source may have '
        'changed. Re-run `add` to re-approve.',
      );
    }
  }

  return failures == 0 ? 0 : 1;
}

/// Re-checks licences upstream. A video's licence can be changed after the fact,
/// and the first anyone would otherwise know is a takedown.
Future<int> _audit(String root) async {
  final manifest = ReferenceManifest.load(root);
  final key = Platform.environment['YOUTUBE_API_KEY'];
  var problems = 0;

  for (final record in manifest.records) {
    final LicenceVerdict verdict;
    if (record.source == 'youtube') {
      if (key == null || key.isEmpty) {
        stdout.writeln('skipped  ${record.id} — YOUTUBE_API_KEY not set');
        continue;
      }
      verdict = await YouTubeSource(apiKey: key).check(record.sourceId);
    } else {
      verdict = await ArchiveSource().check(record.sourceId);
    }

    if (verdict.allowed) {
      stdout.writeln('ok       ${record.id}');
    } else {
      stdout.writeln('REVOKED  ${record.id} — ${verdict.reason}');
      problems++;
    }
  }

  if (problems > 0) {
    stdout.writeln(
      '\n$problems reference(s) no longer carry a usable licence.',
    );
    stdout.writeln('Remove them from the curriculum before shipping.');
  }
  return problems == 0 ? 0 : 1;
}

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    if (!args[i].startsWith('--')) continue;
    final name = args[i].substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      options[name] = args[i + 1];
      i++;
    } else {
      options[name] = 'true';
    }
  }
  return options;
}

void _usage() {
  stderr.writeln('''
Licence-checked ingestion of reference audio.

  add --youtube <id> --as <local-id> [--approved-by <name>]
  add --archive <id> --as <local-id> [--approved-by <name>]
  verify     offline check of files against the manifest
  restore    re-fetch everything the manifest lists
  audit      re-check licences upstream

Nothing downloads until the source states a redistributable licence.
''');
}

String _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'CLAUDE.md')).existsSync() &&
        Directory(p.join(dir.path, 'content')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln('Could not locate the repo root.');
      exit(1);
    }
    dir = parent;
  }
}
