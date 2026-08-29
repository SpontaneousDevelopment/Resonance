/// The curriculum tree: tiers → units → lessons.
///
/// These types are **read-only**. The tree is authored as YAML under
/// `content/curriculum/`, compiled to a single validated JSON seed by
/// `tools/curriculum_build`, and bundled with the app so the tree renders
/// offline on first launch. Nothing at runtime mutates a [Lesson]; user state
/// lives separately in `domain/progress` and is joined by id.
///
/// That separation is deliberate: shipping a curriculum update must never risk
/// a user's progress, and progress must survive a lesson being reworded.
library;

/// How an attempt at a lesson is performed and scored.
///
/// The [requiresNetwork] flag is read by the skill tree to grey a node out
/// *before* the user taps it, rather than failing them at the record screen.
enum LessonType {
  /// Read a known script aloud. Scored on clarity, pace and plosives.
  /// The workhorse of Tiers 1–2 and the MVP's primary type.
  scoredRead(requiresNetwork: false),

  /// Match a target pitch contour. Scored on contour distance.
  pitchMatch(requiresNetwork: false),

  /// Speak along with a reference clip in real time.
  shadowRead(requiresNetwork: false),

  /// One line, several emotional directions. Scored on contrast *between*
  /// takes, so it needs no reference corpus.
  emotionalRange(requiresNetwork: false),

  /// Build and sustain a character voice across a passage. Scored on internal
  /// consistency across the take.
  characterVoice(requiresNetwork: false),

  /// Phoneme-level repetition. The one type that needs cloud forced alignment.
  accentDrill(requiresNetwork: true),

  /// Plosive control, proximity, room noise. Pure DSP, no transcript.
  micTechnique(requiresNetwork: false),

  /// Study an embedded performance and answer prompts about it. No recording;
  /// this is the only type that plays third-party media, and it does so through
  /// the publisher's own player.
  listenAndAnalyse(requiresNetwork: true);

  const LessonType({required this.requiresNetwork});

  final bool requiresNetwork;

  static LessonType fromId(String id) => LessonType.values.firstWhere(
    (t) => t.name == id,
    orElse: () => throw FormatException('Unknown lesson type: $id'),
  );
}

/// Where a lesson's reference audio comes from.
///
/// Every reference in the app carries its provenance, and the UI surfaces it.
/// A user comparing themselves to a synthetic read deserves to know that is
/// what they are hearing.
enum ReferenceSource {
  /// No reference — the lesson scores the user against a rubric alone.
  none,

  /// Public-domain human recording (LibriVox / Internet Archive). Bundled or
  /// cached locally.
  publicDomain,

  /// Creative-Commons-licensed recording, ingested with attribution retained.
  creativeCommons,

  /// Recorded for Resonance.
  original,

  /// Text-to-speech. **Always** labelled as such in the UI — it is a target,
  /// not a performance.
  synthetic,

  /// Streamed from the publisher's embedded player. Never stored.
  embed;

  /// Whether the UI must show an "AI-generated reference" disclosure.
  bool get needsSyntheticDisclosure => this == ReferenceSource.synthetic;

  /// Whether the UI must show an attribution line.
  bool get needsAttribution =>
      this == ReferenceSource.creativeCommons ||
      this == ReferenceSource.publicDomain;

  static ReferenceSource fromId(String id) => ReferenceSource.values.firstWhere(
    (s) => s.name == id,
    orElse: () => throw FormatException('Unknown reference source: $id'),
  );
}

/// A reference clip attached to a lesson.
class LessonReference {
  const LessonReference({
    required this.source,
    this.assetPath,
    this.videoId,
    this.startSeconds,
    this.endSeconds,
    this.attribution,
    this.licenseUrl,
  });

  final ReferenceSource source;

  /// Bundled or cached local audio, for every source except [ReferenceSource.embed].
  final String? assetPath;

  /// Publisher video id, for [ReferenceSource.embed] only.
  final String? videoId;
  final int? startSeconds;
  final int? endSeconds;

  /// Human-readable credit, shown wherever the clip plays.
  final String? attribution;
  final String? licenseUrl;

  factory LessonReference.fromJson(Map<String, dynamic> json) {
    return LessonReference(
      source: ReferenceSource.fromId(json['source'] as String),
      assetPath: json['asset_path'] as String?,
      videoId: json['video_id'] as String?,
      startSeconds: json['start_seconds'] as int?,
      endSeconds: json['end_seconds'] as int?,
      attribution: json['attribution'] as String?,
      licenseUrl: json['license_url'] as String?,
    );
  }
}

/// A single practisable lesson — one session, two to four minutes.
class Lesson {
  const Lesson({
    required this.id,
    required this.unitId,
    required this.title,
    required this.type,
    required this.brief,
    this.script,
    this.reference,
    this.targetWpmMin,
    this.targetWpmMax,
    this.estimatedSeconds = 150,
  });

  /// Stable across content edits. Progress is keyed on this, so it must never
  /// be reused or renumbered.
  final String id;
  final String unitId;
  final String title;
  final LessonType type;

  /// The direction shown before recording — what to actually do.
  final String brief;

  /// The text to be read aloud, where the type has one.
  final String? script;

  final LessonReference? reference;

  /// Target pace band. Outside it costs points; the width of the band is what
  /// makes a lesson forgiving or strict.
  final int? targetWpmMin;
  final int? targetWpmMax;

  final int estimatedSeconds;

  bool get requiresNetwork =>
      type.requiresNetwork || reference?.source == ReferenceSource.embed;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      unitId: json['unit_id'] as String,
      title: json['title'] as String,
      type: LessonType.fromId(json['type'] as String),
      brief: json['brief'] as String,
      script: json['script'] as String?,
      reference: json['reference'] == null
          ? null
          : LessonReference.fromJson(json['reference'] as Map<String, dynamic>),
      targetWpmMin: json['target_wpm_min'] as int?,
      targetWpmMax: json['target_wpm_max'] as int?,
      estimatedSeconds: json['estimated_seconds'] as int? ?? 150,
    );
  }
}

/// A group of lessons plus the check that gates what follows.
class Unit {
  const Unit({
    required this.id,
    required this.tierNumber,
    required this.index,
    required this.title,
    required this.summary,
    required this.lessons,
    this.prerequisiteUnitIds = const [],
    this.isGate = false,
    this.plannedLessonCount,
  });

  final String id;
  final int tierNumber;

  /// Position within the tier, 1-based. Drives the "1.3" style label.
  final int index;
  final String title;
  final String summary;
  final List<Lesson> lessons;

  /// Units that must reach [gateLevel] before this one opens. A list rather
  /// than a single parent because Tier 3 branches.
  final List<String> prerequisiteUnitIds;

  /// A mastery-check unit — its own unlock rule is stricter.
  final bool isGate;

  /// How many lessons this unit will hold once authored, for units whose
  /// content has not been written yet. Lets the tree show a locked unit's true
  /// size instead of "0 lessons", without shipping placeholder content.
  final int? plannedLessonCount;

  /// What the tree should display. Falls back to the planned figure while a
  /// unit is unwritten.
  int get displayLessonCount =>
      lessons.isNotEmpty ? lessons.length : (plannedLessonCount ?? 0);

  /// True once real content exists. Unauthored units are visible but not
  /// enterable — they show the road ahead, which is half the motivation.
  bool get isAuthored => lessons.isNotEmpty;

  /// Level every prerequisite unit must reach for this unit to open.
  static const gateLevel = MasteryLevelRequirement.silver;

  String get label => '$tierNumber.$index';

  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      id: json['id'] as String,
      tierNumber: json['tier'] as int,
      index: json['index'] as int,
      title: json['title'] as String,
      summary: json['summary'] as String,
      isGate: json['is_gate'] as bool? ?? false,
      plannedLessonCount: json['planned_lesson_count'] as int?,
      prerequisiteUnitIds: (json['prerequisites'] as List<dynamic>? ?? const [])
          .cast<String>(),
      lessons: (json['lessons'] as List<dynamic>? ?? const [])
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Marker for the level a gate requires. Kept separate from [MasteryLevel] so
/// the requirement can be tuned per gate later without touching the ladder.
enum MasteryLevelRequirement { bronze, silver, gold }

/// One of the four tiers.
class Tier {
  const Tier({
    required this.number,
    required this.title,
    required this.summary,
    required this.units,
    this.isBranching = false,
  });

  final int number;
  final String title;
  final String summary;
  final List<Unit> units;

  /// Tier 3 — the user picks tracks rather than completing everything.
  final bool isBranching;

  int get lessonCount =>
      units.fold(0, (sum, unit) => sum + unit.lessons.length);

  factory Tier.fromJson(Map<String, dynamic> json) {
    return Tier(
      number: json['number'] as int,
      title: json['title'] as String,
      summary: json['summary'] as String,
      isBranching: json['branching'] as bool? ?? false,
      units: (json['units'] as List<dynamic>)
          .map((e) => Unit.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// The whole tree, as loaded from the compiled seed.
class Curriculum {
  const Curriculum({required this.version, required this.tiers});

  /// Bumped by the build tool. Used to decide whether to re-seed on launch.
  final int version;
  final List<Tier> tiers;

  Iterable<Unit> get allUnits => tiers.expand((t) => t.units);
  Iterable<Lesson> get allLessons => allUnits.expand((u) => u.lessons);

  Unit? unitById(String id) => allUnits.where((u) => u.id == id).firstOrNull;

  Lesson? lessonById(String id) =>
      allLessons.where((l) => l.id == id).firstOrNull;

  factory Curriculum.fromJson(Map<String, dynamic> json) {
    return Curriculum(
      version: json['version'] as int,
      tiers: (json['tiers'] as List<dynamic>)
          .map((e) => Tier.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
