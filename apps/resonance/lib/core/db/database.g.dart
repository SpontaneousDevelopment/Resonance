// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LessonProgressTable extends LessonProgress
    with TableInfo<$LessonProgressTable, LessonProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitIdMeta = const VerificationMeta('unitId');
  @override
  late final GeneratedColumn<String> unitId = GeneratedColumn<String>(
    'unit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _masteryRankMeta = const VerificationMeta(
    'masteryRank',
  );
  @override
  late final GeneratedColumn<int> masteryRank = GeneratedColumn<int>(
    'mastery_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bestScoreMeta = const VerificationMeta(
    'bestScore',
  );
  @override
  late final GeneratedColumn<int> bestScore = GeneratedColumn<int>(
    'best_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPromotedOnMeta = const VerificationMeta(
    'lastPromotedOn',
  );
  @override
  late final GeneratedColumn<DateTime> lastPromotedOn =
      GeneratedColumn<DateTime>(
        'last_promoted_on',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastAttemptedOnMeta = const VerificationMeta(
    'lastAttemptedOn',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptedOn =
      GeneratedColumn<DateTime>(
        'last_attempted_on',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _dueOnMeta = const VerificationMeta('dueOn');
  @override
  late final GeneratedColumn<DateTime> dueOn = GeneratedColumn<DateTime>(
    'due_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stabilityDaysMeta = const VerificationMeta(
    'stabilityDays',
  );
  @override
  late final GeneratedColumn<int> stabilityDays = GeneratedColumn<int>(
    'stability_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    lessonId,
    unitId,
    masteryRank,
    attempts,
    bestScore,
    lastPromotedOn,
    lastAttemptedOn,
    dueOn,
    stabilityDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('unit_id')) {
      context.handle(
        _unitIdMeta,
        unitId.isAcceptableOrUnknown(data['unit_id']!, _unitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_unitIdMeta);
    }
    if (data.containsKey('mastery_rank')) {
      context.handle(
        _masteryRankMeta,
        masteryRank.isAcceptableOrUnknown(
          data['mastery_rank']!,
          _masteryRankMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('best_score')) {
      context.handle(
        _bestScoreMeta,
        bestScore.isAcceptableOrUnknown(data['best_score']!, _bestScoreMeta),
      );
    }
    if (data.containsKey('last_promoted_on')) {
      context.handle(
        _lastPromotedOnMeta,
        lastPromotedOn.isAcceptableOrUnknown(
          data['last_promoted_on']!,
          _lastPromotedOnMeta,
        ),
      );
    }
    if (data.containsKey('last_attempted_on')) {
      context.handle(
        _lastAttemptedOnMeta,
        lastAttemptedOn.isAcceptableOrUnknown(
          data['last_attempted_on']!,
          _lastAttemptedOnMeta,
        ),
      );
    }
    if (data.containsKey('due_on')) {
      context.handle(
        _dueOnMeta,
        dueOn.isAcceptableOrUnknown(data['due_on']!, _dueOnMeta),
      );
    }
    if (data.containsKey('stability_days')) {
      context.handle(
        _stabilityDaysMeta,
        stabilityDays.isAcceptableOrUnknown(
          data['stability_days']!,
          _stabilityDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lessonId};
  @override
  LessonProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonProgressRow(
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      unitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_id'],
      )!,
      masteryRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mastery_rank'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      bestScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_score'],
      )!,
      lastPromotedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_promoted_on'],
      ),
      lastAttemptedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempted_on'],
      ),
      dueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_on'],
      ),
      stabilityDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stability_days'],
      )!,
    );
  }

  @override
  $LessonProgressTable createAlias(String alias) {
    return $LessonProgressTable(attachedDatabase, alias);
  }
}

class LessonProgressRow extends DataClass
    implements Insertable<LessonProgressRow> {
  final String lessonId;
  final String unitId;

  /// 0..5, matching `MasteryLevel.rank`. Stored as an int rather than an enum
  /// name so inserting a level between two existing ones later is a migration
  /// of data, not of strings.
  final int masteryRank;
  final int attempts;
  final int bestScore;

  /// Local calendar day, midnight. Null until the first promotion.
  final DateTime? lastPromotedOn;
  final DateTime? lastAttemptedOn;

  /// Spaced repetition. [dueOn] is when this lesson resurfaces in Refresh;
  /// [stabilityDays] is the current interval, widening on each clean pass.
  final DateTime? dueOn;
  final int stabilityDays;
  const LessonProgressRow({
    required this.lessonId,
    required this.unitId,
    required this.masteryRank,
    required this.attempts,
    required this.bestScore,
    this.lastPromotedOn,
    this.lastAttemptedOn,
    this.dueOn,
    required this.stabilityDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lesson_id'] = Variable<String>(lessonId);
    map['unit_id'] = Variable<String>(unitId);
    map['mastery_rank'] = Variable<int>(masteryRank);
    map['attempts'] = Variable<int>(attempts);
    map['best_score'] = Variable<int>(bestScore);
    if (!nullToAbsent || lastPromotedOn != null) {
      map['last_promoted_on'] = Variable<DateTime>(lastPromotedOn);
    }
    if (!nullToAbsent || lastAttemptedOn != null) {
      map['last_attempted_on'] = Variable<DateTime>(lastAttemptedOn);
    }
    if (!nullToAbsent || dueOn != null) {
      map['due_on'] = Variable<DateTime>(dueOn);
    }
    map['stability_days'] = Variable<int>(stabilityDays);
    return map;
  }

  LessonProgressCompanion toCompanion(bool nullToAbsent) {
    return LessonProgressCompanion(
      lessonId: Value(lessonId),
      unitId: Value(unitId),
      masteryRank: Value(masteryRank),
      attempts: Value(attempts),
      bestScore: Value(bestScore),
      lastPromotedOn: lastPromotedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPromotedOn),
      lastAttemptedOn: lastAttemptedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptedOn),
      dueOn: dueOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dueOn),
      stabilityDays: Value(stabilityDays),
    );
  }

  factory LessonProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonProgressRow(
      lessonId: serializer.fromJson<String>(json['lessonId']),
      unitId: serializer.fromJson<String>(json['unitId']),
      masteryRank: serializer.fromJson<int>(json['masteryRank']),
      attempts: serializer.fromJson<int>(json['attempts']),
      bestScore: serializer.fromJson<int>(json['bestScore']),
      lastPromotedOn: serializer.fromJson<DateTime?>(json['lastPromotedOn']),
      lastAttemptedOn: serializer.fromJson<DateTime?>(json['lastAttemptedOn']),
      dueOn: serializer.fromJson<DateTime?>(json['dueOn']),
      stabilityDays: serializer.fromJson<int>(json['stabilityDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lessonId': serializer.toJson<String>(lessonId),
      'unitId': serializer.toJson<String>(unitId),
      'masteryRank': serializer.toJson<int>(masteryRank),
      'attempts': serializer.toJson<int>(attempts),
      'bestScore': serializer.toJson<int>(bestScore),
      'lastPromotedOn': serializer.toJson<DateTime?>(lastPromotedOn),
      'lastAttemptedOn': serializer.toJson<DateTime?>(lastAttemptedOn),
      'dueOn': serializer.toJson<DateTime?>(dueOn),
      'stabilityDays': serializer.toJson<int>(stabilityDays),
    };
  }

  LessonProgressRow copyWith({
    String? lessonId,
    String? unitId,
    int? masteryRank,
    int? attempts,
    int? bestScore,
    Value<DateTime?> lastPromotedOn = const Value.absent(),
    Value<DateTime?> lastAttemptedOn = const Value.absent(),
    Value<DateTime?> dueOn = const Value.absent(),
    int? stabilityDays,
  }) => LessonProgressRow(
    lessonId: lessonId ?? this.lessonId,
    unitId: unitId ?? this.unitId,
    masteryRank: masteryRank ?? this.masteryRank,
    attempts: attempts ?? this.attempts,
    bestScore: bestScore ?? this.bestScore,
    lastPromotedOn: lastPromotedOn.present
        ? lastPromotedOn.value
        : this.lastPromotedOn,
    lastAttemptedOn: lastAttemptedOn.present
        ? lastAttemptedOn.value
        : this.lastAttemptedOn,
    dueOn: dueOn.present ? dueOn.value : this.dueOn,
    stabilityDays: stabilityDays ?? this.stabilityDays,
  );
  LessonProgressRow copyWithCompanion(LessonProgressCompanion data) {
    return LessonProgressRow(
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      unitId: data.unitId.present ? data.unitId.value : this.unitId,
      masteryRank: data.masteryRank.present
          ? data.masteryRank.value
          : this.masteryRank,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      bestScore: data.bestScore.present ? data.bestScore.value : this.bestScore,
      lastPromotedOn: data.lastPromotedOn.present
          ? data.lastPromotedOn.value
          : this.lastPromotedOn,
      lastAttemptedOn: data.lastAttemptedOn.present
          ? data.lastAttemptedOn.value
          : this.lastAttemptedOn,
      dueOn: data.dueOn.present ? data.dueOn.value : this.dueOn,
      stabilityDays: data.stabilityDays.present
          ? data.stabilityDays.value
          : this.stabilityDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressRow(')
          ..write('lessonId: $lessonId, ')
          ..write('unitId: $unitId, ')
          ..write('masteryRank: $masteryRank, ')
          ..write('attempts: $attempts, ')
          ..write('bestScore: $bestScore, ')
          ..write('lastPromotedOn: $lastPromotedOn, ')
          ..write('lastAttemptedOn: $lastAttemptedOn, ')
          ..write('dueOn: $dueOn, ')
          ..write('stabilityDays: $stabilityDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    lessonId,
    unitId,
    masteryRank,
    attempts,
    bestScore,
    lastPromotedOn,
    lastAttemptedOn,
    dueOn,
    stabilityDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonProgressRow &&
          other.lessonId == this.lessonId &&
          other.unitId == this.unitId &&
          other.masteryRank == this.masteryRank &&
          other.attempts == this.attempts &&
          other.bestScore == this.bestScore &&
          other.lastPromotedOn == this.lastPromotedOn &&
          other.lastAttemptedOn == this.lastAttemptedOn &&
          other.dueOn == this.dueOn &&
          other.stabilityDays == this.stabilityDays);
}

class LessonProgressCompanion extends UpdateCompanion<LessonProgressRow> {
  final Value<String> lessonId;
  final Value<String> unitId;
  final Value<int> masteryRank;
  final Value<int> attempts;
  final Value<int> bestScore;
  final Value<DateTime?> lastPromotedOn;
  final Value<DateTime?> lastAttemptedOn;
  final Value<DateTime?> dueOn;
  final Value<int> stabilityDays;
  final Value<int> rowid;
  const LessonProgressCompanion({
    this.lessonId = const Value.absent(),
    this.unitId = const Value.absent(),
    this.masteryRank = const Value.absent(),
    this.attempts = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.lastPromotedOn = const Value.absent(),
    this.lastAttemptedOn = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.stabilityDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonProgressCompanion.insert({
    required String lessonId,
    required String unitId,
    this.masteryRank = const Value.absent(),
    this.attempts = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.lastPromotedOn = const Value.absent(),
    this.lastAttemptedOn = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.stabilityDays = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : lessonId = Value(lessonId),
       unitId = Value(unitId);
  static Insertable<LessonProgressRow> custom({
    Expression<String>? lessonId,
    Expression<String>? unitId,
    Expression<int>? masteryRank,
    Expression<int>? attempts,
    Expression<int>? bestScore,
    Expression<DateTime>? lastPromotedOn,
    Expression<DateTime>? lastAttemptedOn,
    Expression<DateTime>? dueOn,
    Expression<int>? stabilityDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (lessonId != null) 'lesson_id': lessonId,
      if (unitId != null) 'unit_id': unitId,
      if (masteryRank != null) 'mastery_rank': masteryRank,
      if (attempts != null) 'attempts': attempts,
      if (bestScore != null) 'best_score': bestScore,
      if (lastPromotedOn != null) 'last_promoted_on': lastPromotedOn,
      if (lastAttemptedOn != null) 'last_attempted_on': lastAttemptedOn,
      if (dueOn != null) 'due_on': dueOn,
      if (stabilityDays != null) 'stability_days': stabilityDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonProgressCompanion copyWith({
    Value<String>? lessonId,
    Value<String>? unitId,
    Value<int>? masteryRank,
    Value<int>? attempts,
    Value<int>? bestScore,
    Value<DateTime?>? lastPromotedOn,
    Value<DateTime?>? lastAttemptedOn,
    Value<DateTime?>? dueOn,
    Value<int>? stabilityDays,
    Value<int>? rowid,
  }) {
    return LessonProgressCompanion(
      lessonId: lessonId ?? this.lessonId,
      unitId: unitId ?? this.unitId,
      masteryRank: masteryRank ?? this.masteryRank,
      attempts: attempts ?? this.attempts,
      bestScore: bestScore ?? this.bestScore,
      lastPromotedOn: lastPromotedOn ?? this.lastPromotedOn,
      lastAttemptedOn: lastAttemptedOn ?? this.lastAttemptedOn,
      dueOn: dueOn ?? this.dueOn,
      stabilityDays: stabilityDays ?? this.stabilityDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (unitId.present) {
      map['unit_id'] = Variable<String>(unitId.value);
    }
    if (masteryRank.present) {
      map['mastery_rank'] = Variable<int>(masteryRank.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (bestScore.present) {
      map['best_score'] = Variable<int>(bestScore.value);
    }
    if (lastPromotedOn.present) {
      map['last_promoted_on'] = Variable<DateTime>(lastPromotedOn.value);
    }
    if (lastAttemptedOn.present) {
      map['last_attempted_on'] = Variable<DateTime>(lastAttemptedOn.value);
    }
    if (dueOn.present) {
      map['due_on'] = Variable<DateTime>(dueOn.value);
    }
    if (stabilityDays.present) {
      map['stability_days'] = Variable<int>(stabilityDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressCompanion(')
          ..write('lessonId: $lessonId, ')
          ..write('unitId: $unitId, ')
          ..write('masteryRank: $masteryRank, ')
          ..write('attempts: $attempts, ')
          ..write('bestScore: $bestScore, ')
          ..write('lastPromotedOn: $lastPromotedOn, ')
          ..write('lastAttemptedOn: $lastAttemptedOn, ')
          ..write('dueOn: $dueOn, ')
          ..write('stabilityDays: $stabilityDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts
    with TableInfo<$AttemptsTable, AttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clarityScoreMeta = const VerificationMeta(
    'clarityScore',
  );
  @override
  late final GeneratedColumn<int> clarityScore = GeneratedColumn<int>(
    'clarity_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paceScoreMeta = const VerificationMeta(
    'paceScore',
  );
  @override
  late final GeneratedColumn<int> paceScore = GeneratedColumn<int>(
    'pace_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plosiveScoreMeta = const VerificationMeta(
    'plosiveScore',
  );
  @override
  late final GeneratedColumn<int> plosiveScore = GeneratedColumn<int>(
    'plosive_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordsPerMinuteMeta = const VerificationMeta(
    'wordsPerMinute',
  );
  @override
  late final GeneratedColumn<int> wordsPerMinute = GeneratedColumn<int>(
    'words_per_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coachNoteMeta = const VerificationMeta(
    'coachNote',
  );
  @override
  late final GeneratedColumn<String> coachNote = GeneratedColumn<String>(
    'coach_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonId,
    recordedAt,
    durationMs,
    score,
    clarityScore,
    paceScore,
    plosiveScore,
    wordsPerMinute,
    transcript,
    coachNote,
    audioPath,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('clarity_score')) {
      context.handle(
        _clarityScoreMeta,
        clarityScore.isAcceptableOrUnknown(
          data['clarity_score']!,
          _clarityScoreMeta,
        ),
      );
    }
    if (data.containsKey('pace_score')) {
      context.handle(
        _paceScoreMeta,
        paceScore.isAcceptableOrUnknown(data['pace_score']!, _paceScoreMeta),
      );
    }
    if (data.containsKey('plosive_score')) {
      context.handle(
        _plosiveScoreMeta,
        plosiveScore.isAcceptableOrUnknown(
          data['plosive_score']!,
          _plosiveScoreMeta,
        ),
      );
    }
    if (data.containsKey('words_per_minute')) {
      context.handle(
        _wordsPerMinuteMeta,
        wordsPerMinute.isAcceptableOrUnknown(
          data['words_per_minute']!,
          _wordsPerMinuteMeta,
        ),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('coach_note')) {
      context.handle(
        _coachNoteMeta,
        coachNote.isAcceptableOrUnknown(data['coach_note']!, _coachNoteMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttemptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      clarityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clarity_score'],
      ),
      paceScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pace_score'],
      ),
      plosiveScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plosive_score'],
      ),
      wordsPerMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}words_per_minute'],
      ),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      coachNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coach_note'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class AttemptRow extends DataClass implements Insertable<AttemptRow> {
  final String id;
  final String lessonId;
  final DateTime recordedAt;
  final int durationMs;

  /// 0..100 composite, and the components that produced it. Stored separately
  /// so a rubric reweighting can be recomputed against historical attempts
  /// rather than invalidating them.
  final int score;
  final int? clarityScore;
  final int? paceScore;
  final int? plosiveScore;
  final int? wordsPerMinute;

  /// What the recogniser heard. Used for the coach note and for showing the
  /// user which words were dropped.
  final String? transcript;

  /// The LLM coach note, once it arrives. Null while pending or offline — the
  /// feedback screen is fully usable without it.
  final String? coachNote;

  /// Path to the recording on disk. Encrypted at rest; the file is deleted
  /// when the attempt is, and nothing outside this device ever reads it.
  final String? audioPath;

  /// When the numeric summary reached the server. Null means unsynced.
  /// The audio itself is never synced by this field — sharing a recording is a
  /// separate, explicit action.
  final DateTime? syncedAt;
  const AttemptRow({
    required this.id,
    required this.lessonId,
    required this.recordedAt,
    required this.durationMs,
    required this.score,
    this.clarityScore,
    this.paceScore,
    this.plosiveScore,
    this.wordsPerMinute,
    this.transcript,
    this.coachNote,
    this.audioPath,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['lesson_id'] = Variable<String>(lessonId);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['score'] = Variable<int>(score);
    if (!nullToAbsent || clarityScore != null) {
      map['clarity_score'] = Variable<int>(clarityScore);
    }
    if (!nullToAbsent || paceScore != null) {
      map['pace_score'] = Variable<int>(paceScore);
    }
    if (!nullToAbsent || plosiveScore != null) {
      map['plosive_score'] = Variable<int>(plosiveScore);
    }
    if (!nullToAbsent || wordsPerMinute != null) {
      map['words_per_minute'] = Variable<int>(wordsPerMinute);
    }
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    if (!nullToAbsent || coachNote != null) {
      map['coach_note'] = Variable<String>(coachNote);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      lessonId: Value(lessonId),
      recordedAt: Value(recordedAt),
      durationMs: Value(durationMs),
      score: Value(score),
      clarityScore: clarityScore == null && nullToAbsent
          ? const Value.absent()
          : Value(clarityScore),
      paceScore: paceScore == null && nullToAbsent
          ? const Value.absent()
          : Value(paceScore),
      plosiveScore: plosiveScore == null && nullToAbsent
          ? const Value.absent()
          : Value(plosiveScore),
      wordsPerMinute: wordsPerMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(wordsPerMinute),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      coachNote: coachNote == null && nullToAbsent
          ? const Value.absent()
          : Value(coachNote),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory AttemptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttemptRow(
      id: serializer.fromJson<String>(json['id']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      score: serializer.fromJson<int>(json['score']),
      clarityScore: serializer.fromJson<int?>(json['clarityScore']),
      paceScore: serializer.fromJson<int?>(json['paceScore']),
      plosiveScore: serializer.fromJson<int?>(json['plosiveScore']),
      wordsPerMinute: serializer.fromJson<int?>(json['wordsPerMinute']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      coachNote: serializer.fromJson<String?>(json['coachNote']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lessonId': serializer.toJson<String>(lessonId),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'score': serializer.toJson<int>(score),
      'clarityScore': serializer.toJson<int?>(clarityScore),
      'paceScore': serializer.toJson<int?>(paceScore),
      'plosiveScore': serializer.toJson<int?>(plosiveScore),
      'wordsPerMinute': serializer.toJson<int?>(wordsPerMinute),
      'transcript': serializer.toJson<String?>(transcript),
      'coachNote': serializer.toJson<String?>(coachNote),
      'audioPath': serializer.toJson<String?>(audioPath),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  AttemptRow copyWith({
    String? id,
    String? lessonId,
    DateTime? recordedAt,
    int? durationMs,
    int? score,
    Value<int?> clarityScore = const Value.absent(),
    Value<int?> paceScore = const Value.absent(),
    Value<int?> plosiveScore = const Value.absent(),
    Value<int?> wordsPerMinute = const Value.absent(),
    Value<String?> transcript = const Value.absent(),
    Value<String?> coachNote = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => AttemptRow(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    recordedAt: recordedAt ?? this.recordedAt,
    durationMs: durationMs ?? this.durationMs,
    score: score ?? this.score,
    clarityScore: clarityScore.present ? clarityScore.value : this.clarityScore,
    paceScore: paceScore.present ? paceScore.value : this.paceScore,
    plosiveScore: plosiveScore.present ? plosiveScore.value : this.plosiveScore,
    wordsPerMinute: wordsPerMinute.present
        ? wordsPerMinute.value
        : this.wordsPerMinute,
    transcript: transcript.present ? transcript.value : this.transcript,
    coachNote: coachNote.present ? coachNote.value : this.coachNote,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  AttemptRow copyWithCompanion(AttemptsCompanion data) {
    return AttemptRow(
      id: data.id.present ? data.id.value : this.id,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      score: data.score.present ? data.score.value : this.score,
      clarityScore: data.clarityScore.present
          ? data.clarityScore.value
          : this.clarityScore,
      paceScore: data.paceScore.present ? data.paceScore.value : this.paceScore,
      plosiveScore: data.plosiveScore.present
          ? data.plosiveScore.value
          : this.plosiveScore,
      wordsPerMinute: data.wordsPerMinute.present
          ? data.wordsPerMinute.value
          : this.wordsPerMinute,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      coachNote: data.coachNote.present ? data.coachNote.value : this.coachNote,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttemptRow(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('score: $score, ')
          ..write('clarityScore: $clarityScore, ')
          ..write('paceScore: $paceScore, ')
          ..write('plosiveScore: $plosiveScore, ')
          ..write('wordsPerMinute: $wordsPerMinute, ')
          ..write('transcript: $transcript, ')
          ..write('coachNote: $coachNote, ')
          ..write('audioPath: $audioPath, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lessonId,
    recordedAt,
    durationMs,
    score,
    clarityScore,
    paceScore,
    plosiveScore,
    wordsPerMinute,
    transcript,
    coachNote,
    audioPath,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttemptRow &&
          other.id == this.id &&
          other.lessonId == this.lessonId &&
          other.recordedAt == this.recordedAt &&
          other.durationMs == this.durationMs &&
          other.score == this.score &&
          other.clarityScore == this.clarityScore &&
          other.paceScore == this.paceScore &&
          other.plosiveScore == this.plosiveScore &&
          other.wordsPerMinute == this.wordsPerMinute &&
          other.transcript == this.transcript &&
          other.coachNote == this.coachNote &&
          other.audioPath == this.audioPath &&
          other.syncedAt == this.syncedAt);
}

class AttemptsCompanion extends UpdateCompanion<AttemptRow> {
  final Value<String> id;
  final Value<String> lessonId;
  final Value<DateTime> recordedAt;
  final Value<int> durationMs;
  final Value<int> score;
  final Value<int?> clarityScore;
  final Value<int?> paceScore;
  final Value<int?> plosiveScore;
  final Value<int?> wordsPerMinute;
  final Value<String?> transcript;
  final Value<String?> coachNote;
  final Value<String?> audioPath;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.score = const Value.absent(),
    this.clarityScore = const Value.absent(),
    this.paceScore = const Value.absent(),
    this.plosiveScore = const Value.absent(),
    this.wordsPerMinute = const Value.absent(),
    this.transcript = const Value.absent(),
    this.coachNote = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttemptsCompanion.insert({
    required String id,
    required String lessonId,
    required DateTime recordedAt,
    required int durationMs,
    required int score,
    this.clarityScore = const Value.absent(),
    this.paceScore = const Value.absent(),
    this.plosiveScore = const Value.absent(),
    this.wordsPerMinute = const Value.absent(),
    this.transcript = const Value.absent(),
    this.coachNote = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lessonId = Value(lessonId),
       recordedAt = Value(recordedAt),
       durationMs = Value(durationMs),
       score = Value(score);
  static Insertable<AttemptRow> custom({
    Expression<String>? id,
    Expression<String>? lessonId,
    Expression<DateTime>? recordedAt,
    Expression<int>? durationMs,
    Expression<int>? score,
    Expression<int>? clarityScore,
    Expression<int>? paceScore,
    Expression<int>? plosiveScore,
    Expression<int>? wordsPerMinute,
    Expression<String>? transcript,
    Expression<String>? coachNote,
    Expression<String>? audioPath,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonId != null) 'lesson_id': lessonId,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (score != null) 'score': score,
      if (clarityScore != null) 'clarity_score': clarityScore,
      if (paceScore != null) 'pace_score': paceScore,
      if (plosiveScore != null) 'plosive_score': plosiveScore,
      if (wordsPerMinute != null) 'words_per_minute': wordsPerMinute,
      if (transcript != null) 'transcript': transcript,
      if (coachNote != null) 'coach_note': coachNote,
      if (audioPath != null) 'audio_path': audioPath,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? lessonId,
    Value<DateTime>? recordedAt,
    Value<int>? durationMs,
    Value<int>? score,
    Value<int?>? clarityScore,
    Value<int?>? paceScore,
    Value<int?>? plosiveScore,
    Value<int?>? wordsPerMinute,
    Value<String?>? transcript,
    Value<String?>? coachNote,
    Value<String?>? audioPath,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      recordedAt: recordedAt ?? this.recordedAt,
      durationMs: durationMs ?? this.durationMs,
      score: score ?? this.score,
      clarityScore: clarityScore ?? this.clarityScore,
      paceScore: paceScore ?? this.paceScore,
      plosiveScore: plosiveScore ?? this.plosiveScore,
      wordsPerMinute: wordsPerMinute ?? this.wordsPerMinute,
      transcript: transcript ?? this.transcript,
      coachNote: coachNote ?? this.coachNote,
      audioPath: audioPath ?? this.audioPath,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (clarityScore.present) {
      map['clarity_score'] = Variable<int>(clarityScore.value);
    }
    if (paceScore.present) {
      map['pace_score'] = Variable<int>(paceScore.value);
    }
    if (plosiveScore.present) {
      map['plosive_score'] = Variable<int>(plosiveScore.value);
    }
    if (wordsPerMinute.present) {
      map['words_per_minute'] = Variable<int>(wordsPerMinute.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (coachNote.present) {
      map['coach_note'] = Variable<String>(coachNote.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('score: $score, ')
          ..write('clarityScore: $clarityScore, ')
          ..write('paceScore: $paceScore, ')
          ..write('plosiveScore: $plosiveScore, ')
          ..write('wordsPerMinute: $wordsPerMinute, ')
          ..write('transcript: $transcript, ')
          ..write('coachNote: $coachNote, ')
          ..write('audioPath: $audioPath, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreakStateTable extends StreakState
    with TableInfo<$StreakStateTable, StreakRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestStreakMeta = const VerificationMeta(
    'longestStreak',
  );
  @override
  late final GeneratedColumn<int> longestStreak = GeneratedColumn<int>(
    'longest_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPracticeDayMeta = const VerificationMeta(
    'lastPracticeDay',
  );
  @override
  late final GeneratedColumn<DateTime> lastPracticeDay =
      GeneratedColumn<DateTime>(
        'last_practice_day',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freezesAvailableMeta = const VerificationMeta(
    'freezesAvailable',
  );
  @override
  late final GeneratedColumn<int> freezesAvailable = GeneratedColumn<int>(
    'freezes_available',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _freezeLastEarnedOnMeta =
      const VerificationMeta('freezeLastEarnedOn');
  @override
  late final GeneratedColumn<DateTime> freezeLastEarnedOn =
      GeneratedColumn<DateTime>(
        'freeze_last_earned_on',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currentStreak,
    longestStreak,
    lastPracticeDay,
    freezesAvailable,
    freezeLastEarnedOn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<StreakRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
      );
    }
    if (data.containsKey('longest_streak')) {
      context.handle(
        _longestStreakMeta,
        longestStreak.isAcceptableOrUnknown(
          data['longest_streak']!,
          _longestStreakMeta,
        ),
      );
    }
    if (data.containsKey('last_practice_day')) {
      context.handle(
        _lastPracticeDayMeta,
        lastPracticeDay.isAcceptableOrUnknown(
          data['last_practice_day']!,
          _lastPracticeDayMeta,
        ),
      );
    }
    if (data.containsKey('freezes_available')) {
      context.handle(
        _freezesAvailableMeta,
        freezesAvailable.isAcceptableOrUnknown(
          data['freezes_available']!,
          _freezesAvailableMeta,
        ),
      );
    }
    if (data.containsKey('freeze_last_earned_on')) {
      context.handle(
        _freezeLastEarnedOnMeta,
        freezeLastEarnedOn.isAcceptableOrUnknown(
          data['freeze_last_earned_on']!,
          _freezeLastEarnedOnMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StreakRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_streak'],
      )!,
      longestStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest_streak'],
      )!,
      lastPracticeDay: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_practice_day'],
      ),
      freezesAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}freezes_available'],
      )!,
      freezeLastEarnedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}freeze_last_earned_on'],
      ),
    );
  }

  @override
  $StreakStateTable createAlias(String alias) {
    return $StreakStateTable(attachedDatabase, alias);
  }
}

class StreakRow extends DataClass implements Insertable<StreakRow> {
  final int id;
  final int currentStreak;
  final int longestStreak;

  /// The last local calendar day with a completed session.
  final DateTime? lastPracticeDay;

  /// Freezes in hand. A freeze is spent automatically on the first missed day,
  /// which is the whole point — the user should discover it was saved, not be
  /// asked to save it.
  final int freezesAvailable;
  final DateTime? freezeLastEarnedOn;
  const StreakRow({
    required this.id,
    required this.currentStreak,
    required this.longestStreak,
    this.lastPracticeDay,
    required this.freezesAvailable,
    this.freezeLastEarnedOn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_streak'] = Variable<int>(currentStreak);
    map['longest_streak'] = Variable<int>(longestStreak);
    if (!nullToAbsent || lastPracticeDay != null) {
      map['last_practice_day'] = Variable<DateTime>(lastPracticeDay);
    }
    map['freezes_available'] = Variable<int>(freezesAvailable);
    if (!nullToAbsent || freezeLastEarnedOn != null) {
      map['freeze_last_earned_on'] = Variable<DateTime>(freezeLastEarnedOn);
    }
    return map;
  }

  StreakStateCompanion toCompanion(bool nullToAbsent) {
    return StreakStateCompanion(
      id: Value(id),
      currentStreak: Value(currentStreak),
      longestStreak: Value(longestStreak),
      lastPracticeDay: lastPracticeDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPracticeDay),
      freezesAvailable: Value(freezesAvailable),
      freezeLastEarnedOn: freezeLastEarnedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(freezeLastEarnedOn),
    );
  }

  factory StreakRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakRow(
      id: serializer.fromJson<int>(json['id']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      longestStreak: serializer.fromJson<int>(json['longestStreak']),
      lastPracticeDay: serializer.fromJson<DateTime?>(json['lastPracticeDay']),
      freezesAvailable: serializer.fromJson<int>(json['freezesAvailable']),
      freezeLastEarnedOn: serializer.fromJson<DateTime?>(
        json['freezeLastEarnedOn'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'longestStreak': serializer.toJson<int>(longestStreak),
      'lastPracticeDay': serializer.toJson<DateTime?>(lastPracticeDay),
      'freezesAvailable': serializer.toJson<int>(freezesAvailable),
      'freezeLastEarnedOn': serializer.toJson<DateTime?>(freezeLastEarnedOn),
    };
  }

  StreakRow copyWith({
    int? id,
    int? currentStreak,
    int? longestStreak,
    Value<DateTime?> lastPracticeDay = const Value.absent(),
    int? freezesAvailable,
    Value<DateTime?> freezeLastEarnedOn = const Value.absent(),
  }) => StreakRow(
    id: id ?? this.id,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    lastPracticeDay: lastPracticeDay.present
        ? lastPracticeDay.value
        : this.lastPracticeDay,
    freezesAvailable: freezesAvailable ?? this.freezesAvailable,
    freezeLastEarnedOn: freezeLastEarnedOn.present
        ? freezeLastEarnedOn.value
        : this.freezeLastEarnedOn,
  );
  StreakRow copyWithCompanion(StreakStateCompanion data) {
    return StreakRow(
      id: data.id.present ? data.id.value : this.id,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      longestStreak: data.longestStreak.present
          ? data.longestStreak.value
          : this.longestStreak,
      lastPracticeDay: data.lastPracticeDay.present
          ? data.lastPracticeDay.value
          : this.lastPracticeDay,
      freezesAvailable: data.freezesAvailable.present
          ? data.freezesAvailable.value
          : this.freezesAvailable,
      freezeLastEarnedOn: data.freezeLastEarnedOn.present
          ? data.freezeLastEarnedOn.value
          : this.freezeLastEarnedOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StreakRow(')
          ..write('id: $id, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('lastPracticeDay: $lastPracticeDay, ')
          ..write('freezesAvailable: $freezesAvailable, ')
          ..write('freezeLastEarnedOn: $freezeLastEarnedOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    currentStreak,
    longestStreak,
    lastPracticeDay,
    freezesAvailable,
    freezeLastEarnedOn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakRow &&
          other.id == this.id &&
          other.currentStreak == this.currentStreak &&
          other.longestStreak == this.longestStreak &&
          other.lastPracticeDay == this.lastPracticeDay &&
          other.freezesAvailable == this.freezesAvailable &&
          other.freezeLastEarnedOn == this.freezeLastEarnedOn);
}

class StreakStateCompanion extends UpdateCompanion<StreakRow> {
  final Value<int> id;
  final Value<int> currentStreak;
  final Value<int> longestStreak;
  final Value<DateTime?> lastPracticeDay;
  final Value<int> freezesAvailable;
  final Value<DateTime?> freezeLastEarnedOn;
  const StreakStateCompanion({
    this.id = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.lastPracticeDay = const Value.absent(),
    this.freezesAvailable = const Value.absent(),
    this.freezeLastEarnedOn = const Value.absent(),
  });
  StreakStateCompanion.insert({
    this.id = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.lastPracticeDay = const Value.absent(),
    this.freezesAvailable = const Value.absent(),
    this.freezeLastEarnedOn = const Value.absent(),
  });
  static Insertable<StreakRow> custom({
    Expression<int>? id,
    Expression<int>? currentStreak,
    Expression<int>? longestStreak,
    Expression<DateTime>? lastPracticeDay,
    Expression<int>? freezesAvailable,
    Expression<DateTime>? freezeLastEarnedOn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (longestStreak != null) 'longest_streak': longestStreak,
      if (lastPracticeDay != null) 'last_practice_day': lastPracticeDay,
      if (freezesAvailable != null) 'freezes_available': freezesAvailable,
      if (freezeLastEarnedOn != null)
        'freeze_last_earned_on': freezeLastEarnedOn,
    });
  }

  StreakStateCompanion copyWith({
    Value<int>? id,
    Value<int>? currentStreak,
    Value<int>? longestStreak,
    Value<DateTime?>? lastPracticeDay,
    Value<int>? freezesAvailable,
    Value<DateTime?>? freezeLastEarnedOn,
  }) {
    return StreakStateCompanion(
      id: id ?? this.id,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastPracticeDay: lastPracticeDay ?? this.lastPracticeDay,
      freezesAvailable: freezesAvailable ?? this.freezesAvailable,
      freezeLastEarnedOn: freezeLastEarnedOn ?? this.freezeLastEarnedOn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (longestStreak.present) {
      map['longest_streak'] = Variable<int>(longestStreak.value);
    }
    if (lastPracticeDay.present) {
      map['last_practice_day'] = Variable<DateTime>(lastPracticeDay.value);
    }
    if (freezesAvailable.present) {
      map['freezes_available'] = Variable<int>(freezesAvailable.value);
    }
    if (freezeLastEarnedOn.present) {
      map['freeze_last_earned_on'] = Variable<DateTime>(
        freezeLastEarnedOn.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakStateCompanion(')
          ..write('id: $id, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('lastPracticeDay: $lastPracticeDay, ')
          ..write('freezesAvailable: $freezesAvailable, ')
          ..write('freezeLastEarnedOn: $freezeLastEarnedOn')
          ..write(')'))
        .toString();
  }
}

class $DailyXpTable extends DailyXp with TableInfo<$DailyXpTable, DailyXpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyXpTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<DateTime> day = GeneratedColumn<DateTime>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
    'xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sessionsCompletedMeta = const VerificationMeta(
    'sessionsCompleted',
  );
  @override
  late final GeneratedColumn<int> sessionsCompleted = GeneratedColumn<int>(
    'sessions_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [day, xp, sessionsCompleted];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_xp';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyXpRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    }
    if (data.containsKey('sessions_completed')) {
      context.handle(
        _sessionsCompletedMeta,
        sessionsCompleted.isAcceptableOrUnknown(
          data['sessions_completed']!,
          _sessionsCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DailyXpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyXpRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day'],
      )!,
      xp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp'],
      )!,
      sessionsCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sessions_completed'],
      )!,
    );
  }

  @override
  $DailyXpTable createAlias(String alias) {
    return $DailyXpTable(attachedDatabase, alias);
  }
}

class DailyXpRow extends DataClass implements Insertable<DailyXpRow> {
  final DateTime day;
  final int xp;
  final int sessionsCompleted;
  const DailyXpRow({
    required this.day,
    required this.xp,
    required this.sessionsCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<DateTime>(day);
    map['xp'] = Variable<int>(xp);
    map['sessions_completed'] = Variable<int>(sessionsCompleted);
    return map;
  }

  DailyXpCompanion toCompanion(bool nullToAbsent) {
    return DailyXpCompanion(
      day: Value(day),
      xp: Value(xp),
      sessionsCompleted: Value(sessionsCompleted),
    );
  }

  factory DailyXpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyXpRow(
      day: serializer.fromJson<DateTime>(json['day']),
      xp: serializer.fromJson<int>(json['xp']),
      sessionsCompleted: serializer.fromJson<int>(json['sessionsCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<DateTime>(day),
      'xp': serializer.toJson<int>(xp),
      'sessionsCompleted': serializer.toJson<int>(sessionsCompleted),
    };
  }

  DailyXpRow copyWith({DateTime? day, int? xp, int? sessionsCompleted}) =>
      DailyXpRow(
        day: day ?? this.day,
        xp: xp ?? this.xp,
        sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      );
  DailyXpRow copyWithCompanion(DailyXpCompanion data) {
    return DailyXpRow(
      day: data.day.present ? data.day.value : this.day,
      xp: data.xp.present ? data.xp.value : this.xp,
      sessionsCompleted: data.sessionsCompleted.present
          ? data.sessionsCompleted.value
          : this.sessionsCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyXpRow(')
          ..write('day: $day, ')
          ..write('xp: $xp, ')
          ..write('sessionsCompleted: $sessionsCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, xp, sessionsCompleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyXpRow &&
          other.day == this.day &&
          other.xp == this.xp &&
          other.sessionsCompleted == this.sessionsCompleted);
}

class DailyXpCompanion extends UpdateCompanion<DailyXpRow> {
  final Value<DateTime> day;
  final Value<int> xp;
  final Value<int> sessionsCompleted;
  final Value<int> rowid;
  const DailyXpCompanion({
    this.day = const Value.absent(),
    this.xp = const Value.absent(),
    this.sessionsCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyXpCompanion.insert({
    required DateTime day,
    this.xp = const Value.absent(),
    this.sessionsCompleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day);
  static Insertable<DailyXpRow> custom({
    Expression<DateTime>? day,
    Expression<int>? xp,
    Expression<int>? sessionsCompleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (xp != null) 'xp': xp,
      if (sessionsCompleted != null) 'sessions_completed': sessionsCompleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyXpCompanion copyWith({
    Value<DateTime>? day,
    Value<int>? xp,
    Value<int>? sessionsCompleted,
    Value<int>? rowid,
  }) {
    return DailyXpCompanion(
      day: day ?? this.day,
      xp: xp ?? this.xp,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<DateTime>(day.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (sessionsCompleted.present) {
      map['sessions_completed'] = Variable<int>(sessionsCompleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyXpCompanion(')
          ..write('day: $day, ')
          ..write('xp: $xp, ')
          ..write('sessionsCompleted: $sessionsCompleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parkedMeta = const VerificationMeta('parked');
  @override
  late final GeneratedColumn<bool> parked = GeneratedColumn<bool>(
    'parked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("parked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    entityType,
    entityId,
    payload,
    queuedAt,
    attemptCount,
    lastError,
    parked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('parked')) {
      context.handle(
        _parkedMeta,
        parked.isAcceptableOrUnknown(data['parked']!, _parkedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      parked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}parked'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int seq;

  /// e.g. 'attempt', 'lesson_progress', 'streak'.
  final String entityType;
  final String entityId;

  /// JSON payload, already shaped for the server.
  final String payload;
  final DateTime queuedAt;
  final int attemptCount;
  final String? lastError;

  /// Set when the server has permanently rejected this row.
  ///
  /// Persisted rather than held in memory: a parked row sits at the head of the
  /// queue, so anything that does not skip it blocks every row behind it — and
  /// an in-memory set is lost on relaunch, which would re-block the queue every
  /// session. Kept rather than deleted so a payload bug stays diagnosable.
  final bool parked;
  const OutboxRow({
    required this.seq,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.queuedAt,
    required this.attemptCount,
    this.lastError,
    required this.parked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['parked'] = Variable<bool>(parked);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payload: Value(payload),
      queuedAt: Value(queuedAt),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      parked: Value(parked),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      parked: serializer.fromJson<bool>(json['parked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'parked': serializer.toJson<bool>(parked),
    };
  }

  OutboxRow copyWith({
    int? seq,
    String? entityType,
    String? entityId,
    String? payload,
    DateTime? queuedAt,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    bool? parked,
  }) => OutboxRow(
    seq: seq ?? this.seq,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    queuedAt: queuedAt ?? this.queuedAt,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    parked: parked ?? this.parked,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      parked: data.parked.present ? data.parked.value : this.parked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('seq: $seq, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    entityType,
    entityId,
    payload,
    queuedAt,
    attemptCount,
    lastError,
    parked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.seq == this.seq &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.queuedAt == this.queuedAt &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.parked == this.parked);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> seq;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<DateTime> queuedAt;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<bool> parked;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String entityType,
    required String entityId,
    required String payload,
    required DateTime queuedAt,
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       payload = Value(payload),
       queuedAt = Value(queuedAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<DateTime>? queuedAt,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<bool>? parked,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (parked != null) 'parked': parked,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? payload,
    Value<DateTime>? queuedAt,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<bool>? parked,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      queuedAt: queuedAt ?? this.queuedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      parked: parked ?? this.parked,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (parked.present) {
      map['parked'] = Variable<bool>(parked.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked')
          ..write(')'))
        .toString();
  }
}

class $EnergyStateTable extends EnergyState
    with TableInfo<$EnergyStateTable, EnergyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnergyStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _barsMeta = const VerificationMeta('bars');
  @override
  late final GeneratedColumn<int> bars = GeneratedColumn<int>(
    'bars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _lastSpentAtMeta = const VerificationMeta(
    'lastSpentAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSpentAt = GeneratedColumn<DateTime>(
    'last_spent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consecutiveLowLessonIdMeta =
      const VerificationMeta('consecutiveLowLessonId');
  @override
  late final GeneratedColumn<String> consecutiveLowLessonId =
      GeneratedColumn<String>(
        'consecutive_low_lesson_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _consecutiveLowCountMeta =
      const VerificationMeta('consecutiveLowCount');
  @override
  late final GeneratedColumn<int> consecutiveLowCount = GeneratedColumn<int>(
    'consecutive_low_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bars,
    lastSpentAt,
    consecutiveLowLessonId,
    consecutiveLowCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'energy_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<EnergyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('bars')) {
      context.handle(
        _barsMeta,
        bars.isAcceptableOrUnknown(data['bars']!, _barsMeta),
      );
    }
    if (data.containsKey('last_spent_at')) {
      context.handle(
        _lastSpentAtMeta,
        lastSpentAt.isAcceptableOrUnknown(
          data['last_spent_at']!,
          _lastSpentAtMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_low_lesson_id')) {
      context.handle(
        _consecutiveLowLessonIdMeta,
        consecutiveLowLessonId.isAcceptableOrUnknown(
          data['consecutive_low_lesson_id']!,
          _consecutiveLowLessonIdMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_low_count')) {
      context.handle(
        _consecutiveLowCountMeta,
        consecutiveLowCount.isAcceptableOrUnknown(
          data['consecutive_low_count']!,
          _consecutiveLowCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EnergyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EnergyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bars'],
      )!,
      lastSpentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_spent_at'],
      ),
      consecutiveLowLessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}consecutive_low_lesson_id'],
      ),
      consecutiveLowCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_low_count'],
      )!,
    );
  }

  @override
  $EnergyStateTable createAlias(String alias) {
    return $EnergyStateTable(attachedDatabase, alias);
  }
}

class EnergyRow extends DataClass implements Insertable<EnergyRow> {
  final int id;
  final int bars;

  /// When a bar was last spent. Null when the meter is full.
  final DateTime? lastSpentAt;

  /// The lesson currently being struggled with, and how many consecutive low
  /// scores it has taken. Drives the double cost on a repeat.
  final String? consecutiveLowLessonId;
  final int consecutiveLowCount;
  const EnergyRow({
    required this.id,
    required this.bars,
    this.lastSpentAt,
    this.consecutiveLowLessonId,
    required this.consecutiveLowCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['bars'] = Variable<int>(bars);
    if (!nullToAbsent || lastSpentAt != null) {
      map['last_spent_at'] = Variable<DateTime>(lastSpentAt);
    }
    if (!nullToAbsent || consecutiveLowLessonId != null) {
      map['consecutive_low_lesson_id'] = Variable<String>(
        consecutiveLowLessonId,
      );
    }
    map['consecutive_low_count'] = Variable<int>(consecutiveLowCount);
    return map;
  }

  EnergyStateCompanion toCompanion(bool nullToAbsent) {
    return EnergyStateCompanion(
      id: Value(id),
      bars: Value(bars),
      lastSpentAt: lastSpentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSpentAt),
      consecutiveLowLessonId: consecutiveLowLessonId == null && nullToAbsent
          ? const Value.absent()
          : Value(consecutiveLowLessonId),
      consecutiveLowCount: Value(consecutiveLowCount),
    );
  }

  factory EnergyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EnergyRow(
      id: serializer.fromJson<int>(json['id']),
      bars: serializer.fromJson<int>(json['bars']),
      lastSpentAt: serializer.fromJson<DateTime?>(json['lastSpentAt']),
      consecutiveLowLessonId: serializer.fromJson<String?>(
        json['consecutiveLowLessonId'],
      ),
      consecutiveLowCount: serializer.fromJson<int>(
        json['consecutiveLowCount'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bars': serializer.toJson<int>(bars),
      'lastSpentAt': serializer.toJson<DateTime?>(lastSpentAt),
      'consecutiveLowLessonId': serializer.toJson<String?>(
        consecutiveLowLessonId,
      ),
      'consecutiveLowCount': serializer.toJson<int>(consecutiveLowCount),
    };
  }

  EnergyRow copyWith({
    int? id,
    int? bars,
    Value<DateTime?> lastSpentAt = const Value.absent(),
    Value<String?> consecutiveLowLessonId = const Value.absent(),
    int? consecutiveLowCount,
  }) => EnergyRow(
    id: id ?? this.id,
    bars: bars ?? this.bars,
    lastSpentAt: lastSpentAt.present ? lastSpentAt.value : this.lastSpentAt,
    consecutiveLowLessonId: consecutiveLowLessonId.present
        ? consecutiveLowLessonId.value
        : this.consecutiveLowLessonId,
    consecutiveLowCount: consecutiveLowCount ?? this.consecutiveLowCount,
  );
  EnergyRow copyWithCompanion(EnergyStateCompanion data) {
    return EnergyRow(
      id: data.id.present ? data.id.value : this.id,
      bars: data.bars.present ? data.bars.value : this.bars,
      lastSpentAt: data.lastSpentAt.present
          ? data.lastSpentAt.value
          : this.lastSpentAt,
      consecutiveLowLessonId: data.consecutiveLowLessonId.present
          ? data.consecutiveLowLessonId.value
          : this.consecutiveLowLessonId,
      consecutiveLowCount: data.consecutiveLowCount.present
          ? data.consecutiveLowCount.value
          : this.consecutiveLowCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EnergyRow(')
          ..write('id: $id, ')
          ..write('bars: $bars, ')
          ..write('lastSpentAt: $lastSpentAt, ')
          ..write('consecutiveLowLessonId: $consecutiveLowLessonId, ')
          ..write('consecutiveLowCount: $consecutiveLowCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bars,
    lastSpentAt,
    consecutiveLowLessonId,
    consecutiveLowCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnergyRow &&
          other.id == this.id &&
          other.bars == this.bars &&
          other.lastSpentAt == this.lastSpentAt &&
          other.consecutiveLowLessonId == this.consecutiveLowLessonId &&
          other.consecutiveLowCount == this.consecutiveLowCount);
}

class EnergyStateCompanion extends UpdateCompanion<EnergyRow> {
  final Value<int> id;
  final Value<int> bars;
  final Value<DateTime?> lastSpentAt;
  final Value<String?> consecutiveLowLessonId;
  final Value<int> consecutiveLowCount;
  const EnergyStateCompanion({
    this.id = const Value.absent(),
    this.bars = const Value.absent(),
    this.lastSpentAt = const Value.absent(),
    this.consecutiveLowLessonId = const Value.absent(),
    this.consecutiveLowCount = const Value.absent(),
  });
  EnergyStateCompanion.insert({
    this.id = const Value.absent(),
    this.bars = const Value.absent(),
    this.lastSpentAt = const Value.absent(),
    this.consecutiveLowLessonId = const Value.absent(),
    this.consecutiveLowCount = const Value.absent(),
  });
  static Insertable<EnergyRow> custom({
    Expression<int>? id,
    Expression<int>? bars,
    Expression<DateTime>? lastSpentAt,
    Expression<String>? consecutiveLowLessonId,
    Expression<int>? consecutiveLowCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bars != null) 'bars': bars,
      if (lastSpentAt != null) 'last_spent_at': lastSpentAt,
      if (consecutiveLowLessonId != null)
        'consecutive_low_lesson_id': consecutiveLowLessonId,
      if (consecutiveLowCount != null)
        'consecutive_low_count': consecutiveLowCount,
    });
  }

  EnergyStateCompanion copyWith({
    Value<int>? id,
    Value<int>? bars,
    Value<DateTime?>? lastSpentAt,
    Value<String?>? consecutiveLowLessonId,
    Value<int>? consecutiveLowCount,
  }) {
    return EnergyStateCompanion(
      id: id ?? this.id,
      bars: bars ?? this.bars,
      lastSpentAt: lastSpentAt ?? this.lastSpentAt,
      consecutiveLowLessonId:
          consecutiveLowLessonId ?? this.consecutiveLowLessonId,
      consecutiveLowCount: consecutiveLowCount ?? this.consecutiveLowCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bars.present) {
      map['bars'] = Variable<int>(bars.value);
    }
    if (lastSpentAt.present) {
      map['last_spent_at'] = Variable<DateTime>(lastSpentAt.value);
    }
    if (consecutiveLowLessonId.present) {
      map['consecutive_low_lesson_id'] = Variable<String>(
        consecutiveLowLessonId.value,
      );
    }
    if (consecutiveLowCount.present) {
      map['consecutive_low_count'] = Variable<int>(consecutiveLowCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnergyStateCompanion(')
          ..write('id: $id, ')
          ..write('bars: $bars, ')
          ..write('lastSpentAt: $lastSpentAt, ')
          ..write('consecutiveLowLessonId: $consecutiveLowLessonId, ')
          ..write('consecutiveLowCount: $consecutiveLowCount')
          ..write(')'))
        .toString();
  }
}

class $TakeRecordsTable extends TakeRecords
    with TableInfo<$TakeRecordsTable, TakeRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TakeRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attempts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _takeIndexMeta = const VerificationMeta(
    'takeIndex',
  );
  @override
  late final GeneratedColumn<int> takeIndex = GeneratedColumn<int>(
    'take_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordsPerMinuteMeta = const VerificationMeta(
    'wordsPerMinute',
  );
  @override
  late final GeneratedColumn<int> wordsPerMinute = GeneratedColumn<int>(
    'words_per_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passedSanityMeta = const VerificationMeta(
    'passedSanity',
  );
  @override
  late final GeneratedColumn<bool> passedSanity = GeneratedColumn<bool>(
    'passed_sanity',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("passed_sanity" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    attemptId,
    takeIndex,
    label,
    score,
    wordsPerMinute,
    transcript,
    audioPath,
    durationMs,
    passedSanity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'take_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<TakeRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('take_index')) {
      context.handle(
        _takeIndexMeta,
        takeIndex.isAcceptableOrUnknown(data['take_index']!, _takeIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_takeIndexMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('words_per_minute')) {
      context.handle(
        _wordsPerMinuteMeta,
        wordsPerMinute.isAcceptableOrUnknown(
          data['words_per_minute']!,
          _wordsPerMinuteMeta,
        ),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('passed_sanity')) {
      context.handle(
        _passedSanityMeta,
        passedSanity.isAcceptableOrUnknown(
          data['passed_sanity']!,
          _passedSanityMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attemptId, takeIndex};
  @override
  TakeRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TakeRecord(
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      takeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}take_index'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      ),
      wordsPerMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}words_per_minute'],
      ),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      passedSanity: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}passed_sanity'],
      )!,
    );
  }

  @override
  $TakeRecordsTable createAlias(String alias) {
    return $TakeRecordsTable(attachedDatabase, alias);
  }
}

class TakeRecord extends DataClass implements Insertable<TakeRecord> {
  final String attemptId;

  /// Position in the lesson's take list, 0-based. Recording order is the
  /// lesson's order; there is no backward navigation between takes.
  final int takeIndex;

  /// The authored label, copied rather than referenced. Content can be re-worded
  /// later, and a stored attempt should still say what the user was asked for
  /// at the time.
  final String label;
  final int? score;
  final int? wordsPerMinute;
  final String? transcript;

  /// Path to this take's audio. One file per take, all deleted together.
  final String? audioPath;
  final int durationMs;

  /// False when the take only got through because it was the third consecutive
  /// failure of the sanity gate and the user chose to continue. Recorded so the
  /// rubric's honest low score is distinguishable from a gate that gave up.
  final bool passedSanity;
  const TakeRecord({
    required this.attemptId,
    required this.takeIndex,
    required this.label,
    this.score,
    this.wordsPerMinute,
    this.transcript,
    this.audioPath,
    required this.durationMs,
    required this.passedSanity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attempt_id'] = Variable<String>(attemptId);
    map['take_index'] = Variable<int>(takeIndex);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    if (!nullToAbsent || wordsPerMinute != null) {
      map['words_per_minute'] = Variable<int>(wordsPerMinute);
    }
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['passed_sanity'] = Variable<bool>(passedSanity);
    return map;
  }

  TakeRecordsCompanion toCompanion(bool nullToAbsent) {
    return TakeRecordsCompanion(
      attemptId: Value(attemptId),
      takeIndex: Value(takeIndex),
      label: Value(label),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      wordsPerMinute: wordsPerMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(wordsPerMinute),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      durationMs: Value(durationMs),
      passedSanity: Value(passedSanity),
    );
  }

  factory TakeRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TakeRecord(
      attemptId: serializer.fromJson<String>(json['attemptId']),
      takeIndex: serializer.fromJson<int>(json['takeIndex']),
      label: serializer.fromJson<String>(json['label']),
      score: serializer.fromJson<int?>(json['score']),
      wordsPerMinute: serializer.fromJson<int?>(json['wordsPerMinute']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      passedSanity: serializer.fromJson<bool>(json['passedSanity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attemptId': serializer.toJson<String>(attemptId),
      'takeIndex': serializer.toJson<int>(takeIndex),
      'label': serializer.toJson<String>(label),
      'score': serializer.toJson<int?>(score),
      'wordsPerMinute': serializer.toJson<int?>(wordsPerMinute),
      'transcript': serializer.toJson<String?>(transcript),
      'audioPath': serializer.toJson<String?>(audioPath),
      'durationMs': serializer.toJson<int>(durationMs),
      'passedSanity': serializer.toJson<bool>(passedSanity),
    };
  }

  TakeRecord copyWith({
    String? attemptId,
    int? takeIndex,
    String? label,
    Value<int?> score = const Value.absent(),
    Value<int?> wordsPerMinute = const Value.absent(),
    Value<String?> transcript = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    int? durationMs,
    bool? passedSanity,
  }) => TakeRecord(
    attemptId: attemptId ?? this.attemptId,
    takeIndex: takeIndex ?? this.takeIndex,
    label: label ?? this.label,
    score: score.present ? score.value : this.score,
    wordsPerMinute: wordsPerMinute.present
        ? wordsPerMinute.value
        : this.wordsPerMinute,
    transcript: transcript.present ? transcript.value : this.transcript,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    durationMs: durationMs ?? this.durationMs,
    passedSanity: passedSanity ?? this.passedSanity,
  );
  TakeRecord copyWithCompanion(TakeRecordsCompanion data) {
    return TakeRecord(
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      takeIndex: data.takeIndex.present ? data.takeIndex.value : this.takeIndex,
      label: data.label.present ? data.label.value : this.label,
      score: data.score.present ? data.score.value : this.score,
      wordsPerMinute: data.wordsPerMinute.present
          ? data.wordsPerMinute.value
          : this.wordsPerMinute,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      passedSanity: data.passedSanity.present
          ? data.passedSanity.value
          : this.passedSanity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TakeRecord(')
          ..write('attemptId: $attemptId, ')
          ..write('takeIndex: $takeIndex, ')
          ..write('label: $label, ')
          ..write('score: $score, ')
          ..write('wordsPerMinute: $wordsPerMinute, ')
          ..write('transcript: $transcript, ')
          ..write('audioPath: $audioPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('passedSanity: $passedSanity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    attemptId,
    takeIndex,
    label,
    score,
    wordsPerMinute,
    transcript,
    audioPath,
    durationMs,
    passedSanity,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TakeRecord &&
          other.attemptId == this.attemptId &&
          other.takeIndex == this.takeIndex &&
          other.label == this.label &&
          other.score == this.score &&
          other.wordsPerMinute == this.wordsPerMinute &&
          other.transcript == this.transcript &&
          other.audioPath == this.audioPath &&
          other.durationMs == this.durationMs &&
          other.passedSanity == this.passedSanity);
}

class TakeRecordsCompanion extends UpdateCompanion<TakeRecord> {
  final Value<String> attemptId;
  final Value<int> takeIndex;
  final Value<String> label;
  final Value<int?> score;
  final Value<int?> wordsPerMinute;
  final Value<String?> transcript;
  final Value<String?> audioPath;
  final Value<int> durationMs;
  final Value<bool> passedSanity;
  final Value<int> rowid;
  const TakeRecordsCompanion({
    this.attemptId = const Value.absent(),
    this.takeIndex = const Value.absent(),
    this.label = const Value.absent(),
    this.score = const Value.absent(),
    this.wordsPerMinute = const Value.absent(),
    this.transcript = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.passedSanity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TakeRecordsCompanion.insert({
    required String attemptId,
    required int takeIndex,
    required String label,
    this.score = const Value.absent(),
    this.wordsPerMinute = const Value.absent(),
    this.transcript = const Value.absent(),
    this.audioPath = const Value.absent(),
    required int durationMs,
    this.passedSanity = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : attemptId = Value(attemptId),
       takeIndex = Value(takeIndex),
       label = Value(label),
       durationMs = Value(durationMs);
  static Insertable<TakeRecord> custom({
    Expression<String>? attemptId,
    Expression<int>? takeIndex,
    Expression<String>? label,
    Expression<int>? score,
    Expression<int>? wordsPerMinute,
    Expression<String>? transcript,
    Expression<String>? audioPath,
    Expression<int>? durationMs,
    Expression<bool>? passedSanity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attemptId != null) 'attempt_id': attemptId,
      if (takeIndex != null) 'take_index': takeIndex,
      if (label != null) 'label': label,
      if (score != null) 'score': score,
      if (wordsPerMinute != null) 'words_per_minute': wordsPerMinute,
      if (transcript != null) 'transcript': transcript,
      if (audioPath != null) 'audio_path': audioPath,
      if (durationMs != null) 'duration_ms': durationMs,
      if (passedSanity != null) 'passed_sanity': passedSanity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TakeRecordsCompanion copyWith({
    Value<String>? attemptId,
    Value<int>? takeIndex,
    Value<String>? label,
    Value<int?>? score,
    Value<int?>? wordsPerMinute,
    Value<String?>? transcript,
    Value<String?>? audioPath,
    Value<int>? durationMs,
    Value<bool>? passedSanity,
    Value<int>? rowid,
  }) {
    return TakeRecordsCompanion(
      attemptId: attemptId ?? this.attemptId,
      takeIndex: takeIndex ?? this.takeIndex,
      label: label ?? this.label,
      score: score ?? this.score,
      wordsPerMinute: wordsPerMinute ?? this.wordsPerMinute,
      transcript: transcript ?? this.transcript,
      audioPath: audioPath ?? this.audioPath,
      durationMs: durationMs ?? this.durationMs,
      passedSanity: passedSanity ?? this.passedSanity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (takeIndex.present) {
      map['take_index'] = Variable<int>(takeIndex.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (wordsPerMinute.present) {
      map['words_per_minute'] = Variable<int>(wordsPerMinute.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (passedSanity.present) {
      map['passed_sanity'] = Variable<bool>(passedSanity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TakeRecordsCompanion(')
          ..write('attemptId: $attemptId, ')
          ..write('takeIndex: $takeIndex, ')
          ..write('label: $label, ')
          ..write('score: $score, ')
          ..write('wordsPerMinute: $wordsPerMinute, ')
          ..write('transcript: $transcript, ')
          ..write('audioPath: $audioPath, ')
          ..write('durationMs: $durationMs, ')
          ..write('passedSanity: $passedSanity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ResonanceDatabase extends GeneratedDatabase {
  _$ResonanceDatabase(QueryExecutor e) : super(e);
  $ResonanceDatabaseManager get managers => $ResonanceDatabaseManager(this);
  late final $LessonProgressTable lessonProgress = $LessonProgressTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $StreakStateTable streakState = $StreakStateTable(this);
  late final $DailyXpTable dailyXp = $DailyXpTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $EnergyStateTable energyState = $EnergyStateTable(this);
  late final $TakeRecordsTable takeRecords = $TakeRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lessonProgress,
    attempts,
    streakState,
    dailyXp,
    outbox,
    energyState,
    takeRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'attempts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('take_records', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LessonProgressTableCreateCompanionBuilder =
    LessonProgressCompanion Function({
      required String lessonId,
      required String unitId,
      Value<int> masteryRank,
      Value<int> attempts,
      Value<int> bestScore,
      Value<DateTime?> lastPromotedOn,
      Value<DateTime?> lastAttemptedOn,
      Value<DateTime?> dueOn,
      Value<int> stabilityDays,
      Value<int> rowid,
    });
typedef $$LessonProgressTableUpdateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<String> lessonId,
      Value<String> unitId,
      Value<int> masteryRank,
      Value<int> attempts,
      Value<int> bestScore,
      Value<DateTime?> lastPromotedOn,
      Value<DateTime?> lastAttemptedOn,
      Value<DateTime?> dueOn,
      Value<int> stabilityDays,
      Value<int> rowid,
    });

class $$LessonProgressTableFilterComposer
    extends Composer<_$ResonanceDatabase, $LessonProgressTable> {
  $$LessonProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get masteryRank => $composableBuilder(
    column: $table.masteryRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPromotedOn => $composableBuilder(
    column: $table.lastPromotedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptedOn => $composableBuilder(
    column: $table.lastAttemptedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stabilityDays => $composableBuilder(
    column: $table.stabilityDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonProgressTableOrderingComposer
    extends Composer<_$ResonanceDatabase, $LessonProgressTable> {
  $$LessonProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitId => $composableBuilder(
    column: $table.unitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get masteryRank => $composableBuilder(
    column: $table.masteryRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPromotedOn => $composableBuilder(
    column: $table.lastPromotedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptedOn => $composableBuilder(
    column: $table.lastAttemptedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stabilityDays => $composableBuilder(
    column: $table.stabilityDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonProgressTableAnnotationComposer
    extends Composer<_$ResonanceDatabase, $LessonProgressTable> {
  $$LessonProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get unitId =>
      $composableBuilder(column: $table.unitId, builder: (column) => column);

  GeneratedColumn<int> get masteryRank => $composableBuilder(
    column: $table.masteryRank,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get bestScore =>
      $composableBuilder(column: $table.bestScore, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPromotedOn => $composableBuilder(
    column: $table.lastPromotedOn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptedOn => $composableBuilder(
    column: $table.lastAttemptedOn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => column);

  GeneratedColumn<int> get stabilityDays => $composableBuilder(
    column: $table.stabilityDays,
    builder: (column) => column,
  );
}

class $$LessonProgressTableTableManager
    extends
        RootTableManager<
          _$ResonanceDatabase,
          $LessonProgressTable,
          LessonProgressRow,
          $$LessonProgressTableFilterComposer,
          $$LessonProgressTableOrderingComposer,
          $$LessonProgressTableAnnotationComposer,
          $$LessonProgressTableCreateCompanionBuilder,
          $$LessonProgressTableUpdateCompanionBuilder,
          (
            LessonProgressRow,
            BaseReferences<
              _$ResonanceDatabase,
              $LessonProgressTable,
              LessonProgressRow
            >,
          ),
          LessonProgressRow,
          PrefetchHooks Function()
        > {
  $$LessonProgressTableTableManager(
    _$ResonanceDatabase db,
    $LessonProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> lessonId = const Value.absent(),
                Value<String> unitId = const Value.absent(),
                Value<int> masteryRank = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<DateTime?> lastPromotedOn = const Value.absent(),
                Value<DateTime?> lastAttemptedOn = const Value.absent(),
                Value<DateTime?> dueOn = const Value.absent(),
                Value<int> stabilityDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion(
                lessonId: lessonId,
                unitId: unitId,
                masteryRank: masteryRank,
                attempts: attempts,
                bestScore: bestScore,
                lastPromotedOn: lastPromotedOn,
                lastAttemptedOn: lastAttemptedOn,
                dueOn: dueOn,
                stabilityDays: stabilityDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String lessonId,
                required String unitId,
                Value<int> masteryRank = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<DateTime?> lastPromotedOn = const Value.absent(),
                Value<DateTime?> lastAttemptedOn = const Value.absent(),
                Value<DateTime?> dueOn = const Value.absent(),
                Value<int> stabilityDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion.insert(
                lessonId: lessonId,
                unitId: unitId,
                masteryRank: masteryRank,
                attempts: attempts,
                bestScore: bestScore,
                lastPromotedOn: lastPromotedOn,
                lastAttemptedOn: lastAttemptedOn,
                dueOn: dueOn,
                stabilityDays: stabilityDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$ResonanceDatabase,
      $LessonProgressTable,
      LessonProgressRow,
      $$LessonProgressTableFilterComposer,
      $$LessonProgressTableOrderingComposer,
      $$LessonProgressTableAnnotationComposer,
      $$LessonProgressTableCreateCompanionBuilder,
      $$LessonProgressTableUpdateCompanionBuilder,
      (
        LessonProgressRow,
        BaseReferences<
          _$ResonanceDatabase,
          $LessonProgressTable,
          LessonProgressRow
        >,
      ),
      LessonProgressRow,
      PrefetchHooks Function()
    >;
typedef $$AttemptsTableCreateCompanionBuilder =
    AttemptsCompanion Function({
      required String id,
      required String lessonId,
      required DateTime recordedAt,
      required int durationMs,
      required int score,
      Value<int?> clarityScore,
      Value<int?> paceScore,
      Value<int?> plosiveScore,
      Value<int?> wordsPerMinute,
      Value<String?> transcript,
      Value<String?> coachNote,
      Value<String?> audioPath,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$AttemptsTableUpdateCompanionBuilder =
    AttemptsCompanion Function({
      Value<String> id,
      Value<String> lessonId,
      Value<DateTime> recordedAt,
      Value<int> durationMs,
      Value<int> score,
      Value<int?> clarityScore,
      Value<int?> paceScore,
      Value<int?> plosiveScore,
      Value<int?> wordsPerMinute,
      Value<String?> transcript,
      Value<String?> coachNote,
      Value<String?> audioPath,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

final class $$AttemptsTableReferences
    extends BaseReferences<_$ResonanceDatabase, $AttemptsTable, AttemptRow> {
  $$AttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TakeRecordsTable, List<TakeRecord>>
  _takeRecordsRefsTable(_$ResonanceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.takeRecords,
        aliasName: 'attempts__id__take_records__attempt_id',
      );

  $$TakeRecordsTableProcessedTableManager get takeRecordsRefs {
    final manager = $$TakeRecordsTableTableManager(
      $_db,
      $_db.takeRecords,
    ).filter((f) => f.attemptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_takeRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AttemptsTableFilterComposer
    extends Composer<_$ResonanceDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clarityScore => $composableBuilder(
    column: $table.clarityScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paceScore => $composableBuilder(
    column: $table.paceScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plosiveScore => $composableBuilder(
    column: $table.plosiveScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordsPerMinute => $composableBuilder(
    column: $table.wordsPerMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coachNote => $composableBuilder(
    column: $table.coachNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> takeRecordsRefs(
    Expression<bool> Function($$TakeRecordsTableFilterComposer f) f,
  ) {
    final $$TakeRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.takeRecords,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TakeRecordsTableFilterComposer(
            $db: $db,
            $table: $db.takeRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$ResonanceDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clarityScore => $composableBuilder(
    column: $table.clarityScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paceScore => $composableBuilder(
    column: $table.paceScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plosiveScore => $composableBuilder(
    column: $table.plosiveScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordsPerMinute => $composableBuilder(
    column: $table.wordsPerMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coachNote => $composableBuilder(
    column: $table.coachNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$ResonanceDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get clarityScore => $composableBuilder(
    column: $table.clarityScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paceScore =>
      $composableBuilder(column: $table.paceScore, builder: (column) => column);

  GeneratedColumn<int> get plosiveScore => $composableBuilder(
    column: $table.plosiveScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordsPerMinute => $composableBuilder(
    column: $table.wordsPerMinute,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coachNote =>
      $composableBuilder(column: $table.coachNote, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  Expression<T> takeRecordsRefs<T extends Object>(
    Expression<T> Function($$TakeRecordsTableAnnotationComposer a) f,
  ) {
    final $$TakeRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.takeRecords,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TakeRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.takeRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$ResonanceDatabase,
          $AttemptsTable,
          AttemptRow,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (AttemptRow, $$AttemptsTableReferences),
          AttemptRow,
          PrefetchHooks Function({bool takeRecordsRefs})
        > {
  $$AttemptsTableTableManager(_$ResonanceDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lessonId = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int?> clarityScore = const Value.absent(),
                Value<int?> paceScore = const Value.absent(),
                Value<int?> plosiveScore = const Value.absent(),
                Value<int?> wordsPerMinute = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> coachNote = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                lessonId: lessonId,
                recordedAt: recordedAt,
                durationMs: durationMs,
                score: score,
                clarityScore: clarityScore,
                paceScore: paceScore,
                plosiveScore: plosiveScore,
                wordsPerMinute: wordsPerMinute,
                transcript: transcript,
                coachNote: coachNote,
                audioPath: audioPath,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lessonId,
                required DateTime recordedAt,
                required int durationMs,
                required int score,
                Value<int?> clarityScore = const Value.absent(),
                Value<int?> paceScore = const Value.absent(),
                Value<int?> plosiveScore = const Value.absent(),
                Value<int?> wordsPerMinute = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> coachNote = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion.insert(
                id: id,
                lessonId: lessonId,
                recordedAt: recordedAt,
                durationMs: durationMs,
                score: score,
                clarityScore: clarityScore,
                paceScore: paceScore,
                plosiveScore: plosiveScore,
                wordsPerMinute: wordsPerMinute,
                transcript: transcript,
                coachNote: coachNote,
                audioPath: audioPath,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({takeRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (takeRecordsRefs) db.takeRecords],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (takeRecordsRefs)
                    await $_getPrefetchedData<
                      AttemptRow,
                      $AttemptsTable,
                      TakeRecord
                    >(
                      currentTable: table,
                      referencedTable: $$AttemptsTableReferences
                          ._takeRecordsRefsTable(db),
                      managerFromTypedResult: (p0) => $$AttemptsTableReferences(
                        db,
                        table,
                        p0,
                      ).takeRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.attemptId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$ResonanceDatabase,
      $AttemptsTable,
      AttemptRow,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (AttemptRow, $$AttemptsTableReferences),
      AttemptRow,
      PrefetchHooks Function({bool takeRecordsRefs})
    >;
typedef $$StreakStateTableCreateCompanionBuilder =
    StreakStateCompanion Function({
      Value<int> id,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<DateTime?> lastPracticeDay,
      Value<int> freezesAvailable,
      Value<DateTime?> freezeLastEarnedOn,
    });
typedef $$StreakStateTableUpdateCompanionBuilder =
    StreakStateCompanion Function({
      Value<int> id,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<DateTime?> lastPracticeDay,
      Value<int> freezesAvailable,
      Value<DateTime?> freezeLastEarnedOn,
    });

class $$StreakStateTableFilterComposer
    extends Composer<_$ResonanceDatabase, $StreakStateTable> {
  $$StreakStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPracticeDay => $composableBuilder(
    column: $table.lastPracticeDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freezesAvailable => $composableBuilder(
    column: $table.freezesAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get freezeLastEarnedOn => $composableBuilder(
    column: $table.freezeLastEarnedOn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StreakStateTableOrderingComposer
    extends Composer<_$ResonanceDatabase, $StreakStateTable> {
  $$StreakStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPracticeDay => $composableBuilder(
    column: $table.lastPracticeDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freezesAvailable => $composableBuilder(
    column: $table.freezesAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get freezeLastEarnedOn => $composableBuilder(
    column: $table.freezeLastEarnedOn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StreakStateTableAnnotationComposer
    extends Composer<_$ResonanceDatabase, $StreakStateTable> {
  $$StreakStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPracticeDay => $composableBuilder(
    column: $table.lastPracticeDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freezesAvailable => $composableBuilder(
    column: $table.freezesAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get freezeLastEarnedOn => $composableBuilder(
    column: $table.freezeLastEarnedOn,
    builder: (column) => column,
  );
}

class $$StreakStateTableTableManager
    extends
        RootTableManager<
          _$ResonanceDatabase,
          $StreakStateTable,
          StreakRow,
          $$StreakStateTableFilterComposer,
          $$StreakStateTableOrderingComposer,
          $$StreakStateTableAnnotationComposer,
          $$StreakStateTableCreateCompanionBuilder,
          $$StreakStateTableUpdateCompanionBuilder,
          (
            StreakRow,
            BaseReferences<_$ResonanceDatabase, $StreakStateTable, StreakRow>,
          ),
          StreakRow,
          PrefetchHooks Function()
        > {
  $$StreakStateTableTableManager(
    _$ResonanceDatabase db,
    $StreakStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<DateTime?> lastPracticeDay = const Value.absent(),
                Value<int> freezesAvailable = const Value.absent(),
                Value<DateTime?> freezeLastEarnedOn = const Value.absent(),
              }) => StreakStateCompanion(
                id: id,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastPracticeDay: lastPracticeDay,
                freezesAvailable: freezesAvailable,
                freezeLastEarnedOn: freezeLastEarnedOn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<DateTime?> lastPracticeDay = const Value.absent(),
                Value<int> freezesAvailable = const Value.absent(),
                Value<DateTime?> freezeLastEarnedOn = const Value.absent(),
              }) => StreakStateCompanion.insert(
                id: id,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                lastPracticeDay: lastPracticeDay,
                freezesAvailable: freezesAvailable,
                freezeLastEarnedOn: freezeLastEarnedOn,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StreakStateTableProcessedTableManager =
    ProcessedTableManager<
      _$ResonanceDatabase,
      $StreakStateTable,
      StreakRow,
      $$StreakStateTableFilterComposer,
      $$StreakStateTableOrderingComposer,
      $$StreakStateTableAnnotationComposer,
      $$StreakStateTableCreateCompanionBuilder,
      $$StreakStateTableUpdateCompanionBuilder,
      (
        StreakRow,
        BaseReferences<_$ResonanceDatabase, $StreakStateTable, StreakRow>,
      ),
      StreakRow,
      PrefetchHooks Function()
    >;
typedef $$DailyXpTableCreateCompanionBuilder =
    DailyXpCompanion Function({
      required DateTime day,
      Value<int> xp,
      Value<int> sessionsCompleted,
      Value<int> rowid,
    });
typedef $$DailyXpTableUpdateCompanionBuilder =
    DailyXpCompanion Function({
      Value<DateTime> day,
      Value<int> xp,
      Value<int> sessionsCompleted,
      Value<int> rowid,
    });

class $$DailyXpTableFilterComposer
    extends Composer<_$ResonanceDatabase, $DailyXpTable> {
  $$DailyXpTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionsCompleted => $composableBuilder(
    column: $table.sessionsCompleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyXpTableOrderingComposer
    extends Composer<_$ResonanceDatabase, $DailyXpTable> {
  $$DailyXpTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionsCompleted => $composableBuilder(
    column: $table.sessionsCompleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyXpTableAnnotationComposer
    extends Composer<_$ResonanceDatabase, $DailyXpTable> {
  $$DailyXpTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<int> get sessionsCompleted => $composableBuilder(
    column: $table.sessionsCompleted,
    builder: (column) => column,
  );
}

class $$DailyXpTableTableManager
    extends
        RootTableManager<
          _$ResonanceDatabase,
          $DailyXpTable,
          DailyXpRow,
          $$DailyXpTableFilterComposer,
          $$DailyXpTableOrderingComposer,
          $$DailyXpTableAnnotationComposer,
          $$DailyXpTableCreateCompanionBuilder,
          $$DailyXpTableUpdateCompanionBuilder,
          (
            DailyXpRow,
            BaseReferences<_$ResonanceDatabase, $DailyXpTable, DailyXpRow>,
          ),
          DailyXpRow,
          PrefetchHooks Function()
        > {
  $$DailyXpTableTableManager(_$ResonanceDatabase db, $DailyXpTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyXpTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyXpTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyXpTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> day = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> sessionsCompleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyXpCompanion(
                day: day,
                xp: xp,
                sessionsCompleted: sessionsCompleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime day,
                Value<int> xp = const Value.absent(),
                Value<int> sessionsCompleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyXpCompanion.insert(
                day: day,
                xp: xp,
                sessionsCompleted: sessionsCompleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyXpTableProcessedTableManager =
    ProcessedTableManager<
      _$ResonanceDatabase,
      $DailyXpTable,
      DailyXpRow,
      $$DailyXpTableFilterComposer,
      $$DailyXpTableOrderingComposer,
      $$DailyXpTableAnnotationComposer,
      $$DailyXpTableCreateCompanionBuilder,
      $$DailyXpTableUpdateCompanionBuilder,
      (
        DailyXpRow,
        BaseReferences<_$ResonanceDatabase, $DailyXpTable, DailyXpRow>,
      ),
      DailyXpRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> seq,
      required String entityType,
      required String entityId,
      required String payload,
      required DateTime queuedAt,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<bool> parked,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> seq,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> payload,
      Value<DateTime> queuedAt,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<bool> parked,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$ResonanceDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get parked => $composableBuilder(
    column: $table.parked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$ResonanceDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get parked => $composableBuilder(
    column: $table.parked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$ResonanceDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get parked =>
      $composableBuilder(column: $table.parked, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$ResonanceDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (
            OutboxRow,
            BaseReferences<_$ResonanceDatabase, $OutboxTable, OutboxRow>,
          ),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$ResonanceDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> parked = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                queuedAt: queuedAt,
                attemptCount: attemptCount,
                lastError: lastError,
                parked: parked,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String entityType,
                required String entityId,
                required String payload,
                required DateTime queuedAt,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> parked = const Value.absent(),
              }) => OutboxCompanion.insert(
                seq: seq,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                queuedAt: queuedAt,
                attemptCount: attemptCount,
                lastError: lastError,
                parked: parked,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$ResonanceDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$ResonanceDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$EnergyStateTableCreateCompanionBuilder =
    EnergyStateCompanion Function({
      Value<int> id,
      Value<int> bars,
      Value<DateTime?> lastSpentAt,
      Value<String?> consecutiveLowLessonId,
      Value<int> consecutiveLowCount,
    });
typedef $$EnergyStateTableUpdateCompanionBuilder =
    EnergyStateCompanion Function({
      Value<int> id,
      Value<int> bars,
      Value<DateTime?> lastSpentAt,
      Value<String?> consecutiveLowLessonId,
      Value<int> consecutiveLowCount,
    });

class $$EnergyStateTableFilterComposer
    extends Composer<_$ResonanceDatabase, $EnergyStateTable> {
  $$EnergyStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bars => $composableBuilder(
    column: $table.bars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSpentAt => $composableBuilder(
    column: $table.lastSpentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get consecutiveLowLessonId => $composableBuilder(
    column: $table.consecutiveLowLessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveLowCount => $composableBuilder(
    column: $table.consecutiveLowCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EnergyStateTableOrderingComposer
    extends Composer<_$ResonanceDatabase, $EnergyStateTable> {
  $$EnergyStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bars => $composableBuilder(
    column: $table.bars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSpentAt => $composableBuilder(
    column: $table.lastSpentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get consecutiveLowLessonId => $composableBuilder(
    column: $table.consecutiveLowLessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveLowCount => $composableBuilder(
    column: $table.consecutiveLowCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EnergyStateTableAnnotationComposer
    extends Composer<_$ResonanceDatabase, $EnergyStateTable> {
  $$EnergyStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bars =>
      $composableBuilder(column: $table.bars, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSpentAt => $composableBuilder(
    column: $table.lastSpentAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get consecutiveLowLessonId => $composableBuilder(
    column: $table.consecutiveLowLessonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveLowCount => $composableBuilder(
    column: $table.consecutiveLowCount,
    builder: (column) => column,
  );
}

class $$EnergyStateTableTableManager
    extends
        RootTableManager<
          _$ResonanceDatabase,
          $EnergyStateTable,
          EnergyRow,
          $$EnergyStateTableFilterComposer,
          $$EnergyStateTableOrderingComposer,
          $$EnergyStateTableAnnotationComposer,
          $$EnergyStateTableCreateCompanionBuilder,
          $$EnergyStateTableUpdateCompanionBuilder,
          (
            EnergyRow,
            BaseReferences<_$ResonanceDatabase, $EnergyStateTable, EnergyRow>,
          ),
          EnergyRow,
          PrefetchHooks Function()
        > {
  $$EnergyStateTableTableManager(
    _$ResonanceDatabase db,
    $EnergyStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnergyStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnergyStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnergyStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bars = const Value.absent(),
                Value<DateTime?> lastSpentAt = const Value.absent(),
                Value<String?> consecutiveLowLessonId = const Value.absent(),
                Value<int> consecutiveLowCount = const Value.absent(),
              }) => EnergyStateCompanion(
                id: id,
                bars: bars,
                lastSpentAt: lastSpentAt,
                consecutiveLowLessonId: consecutiveLowLessonId,
                consecutiveLowCount: consecutiveLowCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bars = const Value.absent(),
                Value<DateTime?> lastSpentAt = const Value.absent(),
                Value<String?> consecutiveLowLessonId = const Value.absent(),
                Value<int> consecutiveLowCount = const Value.absent(),
              }) => EnergyStateCompanion.insert(
                id: id,
                bars: bars,
                lastSpentAt: lastSpentAt,
                consecutiveLowLessonId: consecutiveLowLessonId,
                consecutiveLowCount: consecutiveLowCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EnergyStateTableProcessedTableManager =
    ProcessedTableManager<
      _$ResonanceDatabase,
      $EnergyStateTable,
      EnergyRow,
      $$EnergyStateTableFilterComposer,
      $$EnergyStateTableOrderingComposer,
      $$EnergyStateTableAnnotationComposer,
      $$EnergyStateTableCreateCompanionBuilder,
      $$EnergyStateTableUpdateCompanionBuilder,
      (
        EnergyRow,
        BaseReferences<_$ResonanceDatabase, $EnergyStateTable, EnergyRow>,
      ),
      EnergyRow,
      PrefetchHooks Function()
    >;
typedef $$TakeRecordsTableCreateCompanionBuilder =
    TakeRecordsCompanion Function({
      required String attemptId,
      required int takeIndex,
      required String label,
      Value<int?> score,
      Value<int?> wordsPerMinute,
      Value<String?> transcript,
      Value<String?> audioPath,
      required int durationMs,
      Value<bool> passedSanity,
      Value<int> rowid,
    });
typedef $$TakeRecordsTableUpdateCompanionBuilder =
    TakeRecordsCompanion Function({
      Value<String> attemptId,
      Value<int> takeIndex,
      Value<String> label,
      Value<int?> score,
      Value<int?> wordsPerMinute,
      Value<String?> transcript,
      Value<String?> audioPath,
      Value<int> durationMs,
      Value<bool> passedSanity,
      Value<int> rowid,
    });

final class $$TakeRecordsTableReferences
    extends BaseReferences<_$ResonanceDatabase, $TakeRecordsTable, TakeRecord> {
  $$TakeRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AttemptsTable _attemptIdTable(_$ResonanceDatabase db) =>
      db.attempts.createAlias('take_records__attempt_id__attempts__id');

  $$AttemptsTableProcessedTableManager get attemptId {
    final $_column = $_itemColumn<String>('attempt_id')!;

    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attemptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TakeRecordsTableFilterComposer
    extends Composer<_$ResonanceDatabase, $TakeRecordsTable> {
  $$TakeRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get takeIndex => $composableBuilder(
    column: $table.takeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordsPerMinute => $composableBuilder(
    column: $table.wordsPerMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get passedSanity => $composableBuilder(
    column: $table.passedSanity,
    builder: (column) => ColumnFilters(column),
  );

  $$AttemptsTableFilterComposer get attemptId {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TakeRecordsTableOrderingComposer
    extends Composer<_$ResonanceDatabase, $TakeRecordsTable> {
  $$TakeRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get takeIndex => $composableBuilder(
    column: $table.takeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordsPerMinute => $composableBuilder(
    column: $table.wordsPerMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get passedSanity => $composableBuilder(
    column: $table.passedSanity,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttemptsTableOrderingComposer get attemptId {
    final $$AttemptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableOrderingComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TakeRecordsTableAnnotationComposer
    extends Composer<_$ResonanceDatabase, $TakeRecordsTable> {
  $$TakeRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get takeIndex =>
      $composableBuilder(column: $table.takeIndex, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get wordsPerMinute => $composableBuilder(
    column: $table.wordsPerMinute,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get passedSanity => $composableBuilder(
    column: $table.passedSanity,
    builder: (column) => column,
  );

  $$AttemptsTableAnnotationComposer get attemptId {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TakeRecordsTableTableManager
    extends
        RootTableManager<
          _$ResonanceDatabase,
          $TakeRecordsTable,
          TakeRecord,
          $$TakeRecordsTableFilterComposer,
          $$TakeRecordsTableOrderingComposer,
          $$TakeRecordsTableAnnotationComposer,
          $$TakeRecordsTableCreateCompanionBuilder,
          $$TakeRecordsTableUpdateCompanionBuilder,
          (TakeRecord, $$TakeRecordsTableReferences),
          TakeRecord,
          PrefetchHooks Function({bool attemptId})
        > {
  $$TakeRecordsTableTableManager(
    _$ResonanceDatabase db,
    $TakeRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TakeRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TakeRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TakeRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> attemptId = const Value.absent(),
                Value<int> takeIndex = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<int?> wordsPerMinute = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<bool> passedSanity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TakeRecordsCompanion(
                attemptId: attemptId,
                takeIndex: takeIndex,
                label: label,
                score: score,
                wordsPerMinute: wordsPerMinute,
                transcript: transcript,
                audioPath: audioPath,
                durationMs: durationMs,
                passedSanity: passedSanity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String attemptId,
                required int takeIndex,
                required String label,
                Value<int?> score = const Value.absent(),
                Value<int?> wordsPerMinute = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                required int durationMs,
                Value<bool> passedSanity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TakeRecordsCompanion.insert(
                attemptId: attemptId,
                takeIndex: takeIndex,
                label: label,
                score: score,
                wordsPerMinute: wordsPerMinute,
                transcript: transcript,
                audioPath: audioPath,
                durationMs: durationMs,
                passedSanity: passedSanity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TakeRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({attemptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (attemptId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.attemptId,
                                referencedTable: $$TakeRecordsTableReferences
                                    ._attemptIdTable(db),
                                referencedColumn: $$TakeRecordsTableReferences
                                    ._attemptIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TakeRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ResonanceDatabase,
      $TakeRecordsTable,
      TakeRecord,
      $$TakeRecordsTableFilterComposer,
      $$TakeRecordsTableOrderingComposer,
      $$TakeRecordsTableAnnotationComposer,
      $$TakeRecordsTableCreateCompanionBuilder,
      $$TakeRecordsTableUpdateCompanionBuilder,
      (TakeRecord, $$TakeRecordsTableReferences),
      TakeRecord,
      PrefetchHooks Function({bool attemptId})
    >;

class $ResonanceDatabaseManager {
  final _$ResonanceDatabase _db;
  $ResonanceDatabaseManager(this._db);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(_db, _db.lessonProgress);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$StreakStateTableTableManager get streakState =>
      $$StreakStateTableTableManager(_db, _db.streakState);
  $$DailyXpTableTableManager get dailyXp =>
      $$DailyXpTableTableManager(_db, _db.dailyXp);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$EnergyStateTableTableManager get energyState =>
      $$EnergyStateTableTableManager(_db, _db.energyState);
  $$TakeRecordsTableTableManager get takeRecords =>
      $$TakeRecordsTableTableManager(_db, _db.takeRecords);
}
