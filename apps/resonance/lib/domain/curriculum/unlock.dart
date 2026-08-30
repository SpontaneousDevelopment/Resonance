/// Decides which units are open.
///
/// `Unit.prerequisiteUnitIds` and `Unit.gateLevel` have existed since M0 but
/// nothing evaluated them — the tree opened whatever happened to have content.
/// This is that rule, kept pure so the gating can be tested without a database
/// or a widget.
library;

import 'curriculum.dart';
import 'mastery.dart';

/// Why a unit is in the state it is. Surfaced to the user, so the wording is
/// product copy.
enum LockReason {
  /// Open.
  unlocked,

  /// Prerequisites not yet at the required level.
  prerequisitesIncomplete,

  /// Open in principle, but nobody has written the lessons yet.
  notYetAuthored,
}

class UnitUnlockState {
  const UnitUnlockState({
    required this.unitId,
    required this.reason,
    this.blockingUnitIds = const [],
    this.lessonsRemaining = 0,
  });

  final String unitId;
  final LockReason reason;

  /// Units still holding this one closed.
  final List<String> blockingUnitIds;

  /// How many lessons in the blocking units still need to reach the gate level.
  /// Lets the UI say "3 more lessons at Silver" rather than a bare padlock.
  final int lessonsRemaining;

  bool get isOpen => reason == LockReason.unlocked;
}

class UnlockEvaluator {
  const UnlockEvaluator();

  /// Level every lesson in a prerequisite unit must reach.
  ///
  /// Silver rather than Bronze: Bronze means passed once, which is a single
  /// good take and often luck. Silver means it was passed again on a later day,
  /// which is the first point the ladder has evidence of retention.
  static const requiredLevel = MasteryLevel.silver;

  /// Proportion of a unit's lessons that must reach [requiredLevel]. Not 100%,
  /// so one stubborn lesson cannot wall off the rest of the tree.
  static const requiredProportion = 0.8;

  /// Evaluates every unit in the curriculum against the user's mastery.
  ///
  /// [mastery] is keyed by lesson id; a missing entry means never attempted.
  Map<String, UnitUnlockState> evaluate({
    required Curriculum curriculum,
    required Map<String, Mastery> mastery,
  }) {
    final states = <String, UnitUnlockState>{};

    for (final unit in curriculum.allUnits) {
      final blocking = <String>[];
      var remaining = 0;

      for (final prerequisiteId in unit.prerequisiteUnitIds) {
        final prerequisite = curriculum.unitById(prerequisiteId);
        // A dangling prerequisite is a build error the curriculum compiler
        // already rejects. If one reaches here anyway, treat it as satisfied
        // rather than walling off the tree over a content mistake.
        if (prerequisite == null || !prerequisite.isAuthored) continue;

        final short = _lessonsShortOfGate(prerequisite, mastery);
        if (short > 0) {
          blocking.add(prerequisiteId);
          remaining += short;
        }
      }

      final LockReason reason;
      if (blocking.isNotEmpty) {
        reason = LockReason.prerequisitesIncomplete;
      } else if (!unit.isAuthored) {
        reason = LockReason.notYetAuthored;
      } else {
        reason = LockReason.unlocked;
      }

      states[unit.id] = UnitUnlockState(
        unitId: unit.id,
        reason: reason,
        blockingUnitIds: blocking,
        lessonsRemaining: remaining,
      );
    }

    return states;
  }

  /// How many more lessons in [unit] must reach the gate for it to count as
  /// satisfied. Zero means satisfied.
  int _lessonsShortOfGate(Unit unit, Map<String, Mastery> mastery) {
    if (unit.lessons.isEmpty) return 0;

    final needed = (unit.lessons.length * requiredProportion).ceil();
    final reached = unit.lessons
        .where((l) => (mastery[l.id] ?? const Mastery.fresh()).level >= requiredLevel)
        .length;

    final short = needed - reached;
    return short > 0 ? short : 0;
  }
}
