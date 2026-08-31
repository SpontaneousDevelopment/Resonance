// Compiles `content/curriculum/*.yaml` into a single validated JSON seed at
// `apps/resonance/assets/seed/curriculum.json`.
//
// Run from the repo root:
//   fvm dart run tools/curriculum_build/bin/build.dart
//
// The validation here is the point. A broken curriculum is not a runtime error
// we want to discover on a user's phone — a dangling prerequisite or a
// duplicate lesson id should fail the build, loudly, in CI.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Bumped whenever the seed's shape changes. The app compares this against the
/// version it last imported to decide whether to re-seed on launch.
const seedVersion = 1;

const _validLessonTypes = {
  'scoredRead',
  'pitchMatch',
  'shadowRead',
  'emotionalRange',
  'characterVoice',
  'accentDrill',
  'micTechnique',
  'listenAndAnalyse',
};

const _validReferenceSources = {
  'none',
  'publicDomain',
  'creativeCommons',
  'original',
  'synthetic',
  'embed',
};

/// A set, not a list: one structural mistake can be reached down several
/// paths, and reporting it eight times buries the other seven errors.
final _errors = <String>{};
void _fail(String message) => _errors.add(message);

final _warnings = <String>{};
void _warn(String message) => _warnings.add(message);

/// Phrases that read as coaching rather than as something to perform.
///
/// A script is the text the user says out loud; direction belongs in `brief`.
/// Mixing them is easy to do and hard to see in YAML, and the result is a user
/// dutifully reading "keep the tempo even" into a microphone — which is then
/// scored against the target transcript as though it were part of the line.
///
/// A heuristic, so it warns rather than fails: a genuine script may well
/// contain "let the". The author decides.
const _directionPhrases = [
  'keep the tempo',
  'keep each',
  'do not push',
  "don't push",
  'let the consonant',
  'let the vowel',
  'try to',
  'remember to',
  'focus on',
  'notice how',
  'read it again',
];

void main(List<String> args) {
  final repoRoot = _findRepoRoot();
  final contentDir = Directory(p.join(repoRoot, 'content', 'curriculum'));

  if (!contentDir.existsSync()) {
    stderr.writeln('No curriculum directory at ${contentDir.path}');
    exit(1);
  }

  final tierFiles =
      contentDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (tierFiles.isEmpty) {
    stderr.writeln('No .yaml files in ${contentDir.path}');
    exit(1);
  }

  final tiers = <Map<String, dynamic>>[];
  for (final file in tierFiles) {
    final relative = p.relative(file.path, from: repoRoot);
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! Map) {
      _fail('$relative: top level must be a mapping');
      continue;
    }
    tiers.add(_convertTier(_toMap(doc), relative));
  }

  _validateTree(tiers);

  if (_warnings.isNotEmpty) {
    stderr.writeln('\n${_warnings.length} warning(s):\n');
    for (final w in _warnings) {
      stderr.writeln('  ! $w');
    }
    stderr.writeln('');
  }

  if (_errors.isNotEmpty) {
    stderr.writeln(
      '\nCurriculum build failed with ${_errors.length} error(s):\n',
    );
    for (final e in _errors) {
      stderr.writeln('  • $e');
    }
    stderr.writeln('');
    exit(1);
  }

  final seed = <String, dynamic>{'version': seedVersion, 'tiers': tiers};

  final outFile = File(
    p.join(repoRoot, 'apps', 'resonance', 'assets', 'seed', 'curriculum.json'),
  )..parent.createSync(recursive: true);
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(seed));

  final unitCount = tiers.fold<int>(
    0,
    (sum, t) => sum + (t['units'] as List).length,
  );
  final lessonCount = tiers.fold<int>(
    0,
    (sum, t) =>
        sum +
        (t['units'] as List).fold<int>(
          0,
          (s, u) => s + ((u as Map)['lessons'] as List).length,
        ),
  );

  stdout.writeln(
    'Curriculum seed written to '
    '${p.relative(outFile.path, from: repoRoot)}',
  );
  stdout.writeln(
    '  ${tiers.length} tier(s) · $unitCount unit(s) · '
    '$lessonCount authored lesson(s)',
  );
}

// ── Conversion ──────────────────────────────────────────────────────────────

Map<String, dynamic> _convertTier(Map<String, dynamic> raw, String source) {
  final number = raw['number'];
  if (number is! int) _fail('$source: tier `number` must be an integer');

  final units = <Map<String, dynamic>>[];
  final rawUnits = raw['units'];
  if (rawUnits is! List) {
    _fail('$source: tier is missing a `units` list');
  } else {
    for (final u in rawUnits) {
      if (u is! Map) {
        _fail('$source: each unit must be a mapping');
        continue;
      }
      units.add(_convertUnit(_toMap(u), source));
    }
  }

  return {
    'number': number,
    'title': raw['title'],
    'summary': _squash(raw['summary'] as String?),
    'branching': raw['branching'] ?? false,
    'units': units,
  };
}

Map<String, dynamic> _convertUnit(Map<String, dynamic> raw, String source) {
  final id = raw['id'];
  if (id is! String || id.isEmpty) _fail('$source: unit is missing an `id`');

  final lessons = <Map<String, dynamic>>[];
  final rawLessons = raw['lessons'];
  if (rawLessons is List) {
    for (final l in rawLessons) {
      if (l is! Map) {
        _fail('$source: unit $id — each lesson must be a mapping');
        continue;
      }
      lessons.add(_convertLesson(_toMap(l), source, id as String));
    }
  } else if (rawLessons != null) {
    _fail('$source: unit $id — `lessons` must be a list');
  }

  if (lessons.isEmpty && raw['planned_lesson_count'] == null) {
    _fail(
      '$source: unit $id has no lessons and no `planned_lesson_count`. '
      'Unauthored units must declare their intended size.',
    );
  }

  return {
    'id': id,
    'tier': raw['tier'],
    'index': raw['index'],
    'title': raw['title'],
    'summary': _squash(raw['summary'] as String?),
    'is_gate': raw['is_gate'] ?? false,
    'planned_lesson_count': raw['planned_lesson_count'],
    'prerequisites':
        (raw['prerequisites'] as List?)?.cast<String>() ?? const <String>[],
    'lessons': lessons,
  };
}

Map<String, dynamic> _convertLesson(
  Map<String, dynamic> raw,
  String source,
  String unitId,
) {
  final id = raw['id'];
  if (id is! String || id.isEmpty) {
    _fail('$source: unit $unitId — lesson is missing an `id`');
  }

  final type = raw['type'];
  if (type is! String || !_validLessonTypes.contains(type)) {
    _fail(
      '$source: lesson $id — unknown type "$type". '
      'Valid: ${_validLessonTypes.join(", ")}',
    );
  }

  if (raw['unit_id'] != null && raw['unit_id'] != unitId) {
    _fail(
      '$source: lesson $id — declares unit_id "${raw['unit_id']}" but '
      'is nested under "$unitId"',
    );
  }

  // Types that score speech against a written target need that target.
  const needsScript = {
    'scoredRead',
    'shadowRead',
    'emotionalRange',
    'characterVoice',
    'accentDrill',
  };
  final script = _squash(raw['script'] as String?);
  if (script != null) {
    final lower = script.toLowerCase();
    for (final phrase in _directionPhrases) {
      if (lower.contains(phrase)) {
        _warn(
          '$source: lesson $id — the script contains "$phrase", which reads '
          'like direction. Scripts are spoken aloud verbatim and scored '
          'against; move coaching into `brief`.',
        );
      }
    }
  }

  if (needsScript.contains(type) && (script == null || script.isEmpty)) {
    _fail('$source: lesson $id — type "$type" requires a `script`');
  }

  final reference = raw['reference'] == null
      ? null
      : _convertReference(
          _toMap(raw['reference'] as Map),
          source,
          id as String,
        );

  final wpmMin = raw['target_wpm_min'];
  final wpmMax = raw['target_wpm_max'];
  if (wpmMin is int && wpmMax is int && wpmMin >= wpmMax) {
    _fail(
      '$source: lesson $id — target_wpm_min ($wpmMin) must be below '
      'target_wpm_max ($wpmMax)',
    );
  }

  return {
    'id': id,
    'unit_id': unitId,
    'title': raw['title'],
    'type': type,
    'brief': _squash(raw['brief'] as String?),
    'script': script,
    'reference': reference,
    'target_wpm_min': wpmMin,
    'target_wpm_max': wpmMax,
    'estimated_seconds': raw['estimated_seconds'] ?? 150,
  };
}

Map<String, dynamic> _convertReference(
  Map<String, dynamic> raw,
  String source,
  String lessonId,
) {
  final refSource = raw['source'];
  if (refSource is! String || !_validReferenceSources.contains(refSource)) {
    _fail('$source: lesson $lessonId — unknown reference source "$refSource"');
  }

  // Provenance is not optional. A reference we cannot credit is a reference we
  // cannot ship, so this is a build error rather than a runtime fallback.
  if (refSource == 'creativeCommons' || refSource == 'publicDomain') {
    if (raw['attribution'] == null) {
      _fail(
        '$source: lesson $lessonId — "$refSource" reference requires an '
        '`attribution`',
      );
    }
  }
  final awaiting = raw['awaiting_selection'] == true;

  if (refSource == 'embed' && raw['video_id'] == null && !awaiting) {
    _fail(
      '$source: lesson $lessonId — "embed" reference requires a `video_id`, '
      'or `awaiting_selection: true` if the clip has not been chosen yet',
    );
  }
  if (awaiting && raw['video_id'] != null) {
    _fail(
      '$source: lesson $lessonId — `awaiting_selection` is set but a '
      '`video_id` is present. One of them is wrong, and shipping a clip '
      'nobody chose is the worse outcome.',
    );
  }
  if (awaiting) {
    _warn(
      '$source: lesson $lessonId — awaiting a clip selection; the lesson will '
      'not open in the app until one is set.',
    );
  }
  if (refSource != 'embed' &&
      refSource != 'none' &&
      raw['asset_path'] == null) {
    _fail(
      '$source: lesson $lessonId — "$refSource" reference requires an '
      '`asset_path`',
    );
  }

  return {
    'source': refSource,
    'asset_path': raw['asset_path'],
    'video_id': raw['video_id'],
    'start_seconds': raw['start_seconds'],
    'end_seconds': raw['end_seconds'],
    'attribution': raw['attribution'],
    'license_url': raw['license_url'],
    'awaiting_selection': awaiting,
  };
}

// ── Whole-tree validation ───────────────────────────────────────────────────

void _validateTree(List<Map<String, dynamic>> tiers) {
  final unitIds = <String>{};
  final lessonIds = <String>{};
  final allPrerequisites = <String, List<String>>{};

  for (final tier in tiers) {
    for (final unit in (tier['units'] as List).cast<Map<String, dynamic>>()) {
      final id = unit['id'] as String?;
      if (id == null) continue;

      if (!unitIds.add(id)) _fail('Duplicate unit id: $id');

      allPrerequisites[id] = (unit['prerequisites'] as List).cast<String>();

      for (final lesson
          in (unit['lessons'] as List).cast<Map<String, dynamic>>()) {
        final lessonId = lesson['id'] as String?;
        if (lessonId == null) continue;
        if (!lessonIds.add(lessonId)) {
          _fail('Duplicate lesson id: $lessonId');
        }
      }
    }
  }

  for (final entry in allPrerequisites.entries) {
    for (final prerequisite in entry.value) {
      if (!unitIds.contains(prerequisite)) {
        _fail(
          'Unit ${entry.key} requires "$prerequisite", which does not exist',
        );
      }
    }
  }

  _detectCycles(allPrerequisites);
}

/// Depth-first cycle detection. A cycle in the prerequisite graph would leave
/// the affected units permanently unreachable, which is invisible in review and
/// obvious to a user who can never unlock anything.
void _detectCycles(Map<String, List<String>> graph) {
  final visiting = <String>{};
  final done = <String>{};

  bool visit(String node, List<String> path) {
    if (done.contains(node)) return false;
    if (!visiting.add(node)) {
      final cycleStart = path.indexOf(node);
      final cycle = path.sublist(cycleStart < 0 ? 0 : cycleStart);
      // Rotate so the cycle always starts at its alphabetically-first member.
      // The same loop entered from a different node is the same bug.
      final pivot = cycle.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
      final rotation = cycle.indexOf(pivot);
      final canonical = [
        ...cycle.sublist(rotation),
        ...cycle.sublist(0, rotation),
        pivot,
      ];
      _fail('Prerequisite cycle: ${canonical.join(" → ")}');
      return true;
    }
    for (final next in graph[node] ?? const <String>[]) {
      if (visit(next, [...path, node])) {
        visiting.remove(node);
        return true;
      }
    }
    visiting.remove(node);
    done.add(node);
    return false;
  }

  for (final node in graph.keys) {
    visit(node, const []);
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Map<String, dynamic> _toMap(Map source) => source.map(
  (k, v) => MapEntry(k.toString(), v is YamlList ? v.toList() : v),
);

/// Collapses the newlines that YAML folded scalars leave behind, so a script
/// authored across several lines renders as one paragraph.
String? _squash(String? value) {
  if (value == null) return null;
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(dir.path, 'content')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln(
        'Could not locate the repo root from ${Directory.current}',
      );
      exit(1);
    }
    dir = parent;
  }
}
