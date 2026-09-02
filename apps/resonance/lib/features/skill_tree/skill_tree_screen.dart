import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/curriculum_repository.dart';
import '../../core/progress/progress_repository.dart';
import '../../core/sensory/sensory_director.dart';
import '../../domain/sensory/sensory_cue.dart';
import '../../domain/curriculum/lesson_unlock.dart';
import '../../domain/curriculum/unlock.dart';
import 'progress_header.dart';
import '../../domain/curriculum/curriculum.dart';
import '../../domain/curriculum/mastery.dart';
import '../../ui/tokens/motion.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';
import 'lesson_node.dart';
import 'unit_node.dart';

/// The skill tree — the app's home.
///
/// Deliberately a vertical list of units rather than a branching map at this
/// stage. Tier 1 is linear, so a map would be decoration; the branching layout
/// arrives with Tier 3, where it carries real information.
class SkillTreeScreen extends ConsumerWidget {
  const SkillTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = ref.watch(curriculumProvider);
    final mastery = ref.watch(masteryProvider);

    return Scaffold(
      body: SafeArea(
        child: curriculum.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _SeedError(error: error),
          // Mastery streams off the local database and resolves in a frame or
          // two. Rendering the tree immediately and letting the rings fill in
          // avoids a spinner nobody would see.
          data: (data) =>
              _Tree(curriculum: data, mastery: mastery.value ?? const {}),
        ),
      ),
    );
  }
}

class _Tree extends ConsumerStatefulWidget {
  const _Tree({required this.curriculum, required this.mastery});

  final Curriculum curriculum;
  final Map<String, Mastery> mastery;

  @override
  ConsumerState<_Tree> createState() => _TreeState();
}

class _TreeState extends ConsumerState<_Tree> {
  static const _evaluator = UnlockEvaluator();
  static const _lessonEvaluator = LessonUnlockEvaluator();

  /// The one unit showing its lessons, if any.
  ///
  /// One at a time: the tree is a list of choices, and two units open at once
  /// turns it into a wall of twelve. Collapsing the previous one is also what
  /// makes the newly opened unit land where the user is already looking.
  String? _expandedUnitId;

  Curriculum get curriculum => widget.curriculum;
  Map<String, Mastery> get mastery => widget.mastery;

  void _toggle(Unit unit) {
    final director = ref.read(sensoryDirectorProvider);
    // Motion and haptics both go through the sensory layer rather than being
    // improvised here, so this screen honours reduced motion the same way every
    // other moment in the app does.
    director.syncWith(context);
    final opening = _expandedUnitId != unit.id;
    director.play(
      opening
          ? const FeedbackChoreography().forUnitExpand()
          : const FeedbackChoreography().forUnitCollapse(),
    );
    setState(() => _expandedUnitId = opening ? unit.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gutter = context.gutter;
    final unlockStates = _evaluator.evaluate(
      curriculum: curriculum,
      mastery: mastery,
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            gutter,
            ResSpace.loose,
            gutter,
            ResSpace.base,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProgressHeader(),
                const SizedBox(height: ResSpace.loose),
                Text(
                  'YOUR PATH',
                  style: ResType.label.copyWith(color: colors.inkFaint),
                ),
                const SizedBox(height: ResSpace.snug),
                Text(
                  'Foundations',
                  style: ResType.hero.copyWith(color: colors.ink),
                ),
                const SizedBox(height: ResSpace.tight),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Text(
                    curriculum.tiers.first.summary,
                    style: ResType.body.copyWith(color: colors.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final tier in curriculum.tiers) ...[
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            sliver: SliverToBoxAdapter(
              child: _TierHeader(tier: tier, unlockStates: unlockStates),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              ResSpace.base,
              gutter,
              ResSpace.section,
            ),
            sliver: SliverList.separated(
              itemCount: tier.units.length,
              separatorBuilder: (_, _) => const SizedBox(height: ResSpace.snug),
              itemBuilder: (context, index) {
                final unit = tier.units[index];
                final isOpen = unlockStates[unit.id]?.isOpen ?? false;
                final expanded = _expandedUnitId == unit.id;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UnitNode(
                      unit: unit,
                      // Whatever the deepest lesson reached is. The unit ring
                      // summarises; the per-lesson rings below are exact.
                      mastery: _bestMasteryIn(unit),
                      isUnlocked: isOpen,
                      isExpanded: expanded,
                      onTap: isOpen ? () => _toggle(unit) : null,
                    ),
                    // Expands in place rather than pushing a screen. The unit
                    // card stays where it was, so the lessons read as being
                    // inside the thing that was tapped.
                    _LessonList(
                      unit: unit,
                      expanded: expanded,
                      mastery: mastery,
                      unitIsOpen: isOpen,
                      evaluator: _lessonEvaluator,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

extension on _TreeState {
  /// The highest level reached on any lesson in a unit.
  ///
  /// A unit-level ring from lesson-level data has to summarise somehow; the
  /// furthest reached is the honest read of "how deep am I in this", where an
  /// average would drag a strong unit down for one untouched lesson.
  Mastery _bestMasteryIn(Unit unit) {
    var best = const Mastery.fresh();
    for (final lesson in unit.lessons) {
      final m = mastery[lesson.id];
      if (m != null && m.level.rank > best.level.rank) best = m;
    }
    return best;
  }
}

class _TierHeader extends StatelessWidget {
  const _TierHeader({required this.tier, required this.unlockStates});

  final Tier tier;
  final Map<String, UnitUnlockState> unlockStates;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tierColor = colors.tier(tier.number);
    // Counts units the user can actually enter, not units that happen to
    // have content — the label says "open", and those two sets diverge as
    // soon as gating does any work.
    final authored = tier.units
        .where((u) => unlockStates[u.id]?.isOpen ?? false)
        .length;
    final total = tier.units.length;

    return Padding(
      padding: const EdgeInsets.only(top: ResSpace.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 2, color: tierColor),
          const SizedBox(height: ResSpace.snug),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'TIER ${tier.number}',
                style: ResType.label.copyWith(color: tierColor),
              ),
              const SizedBox(width: ResSpace.snug),
              Expanded(
                child: Text(
                  tier.title,
                  style: ResType.heading.copyWith(color: colors.ink),
                ),
              ),
              Text(
                '$authored/$total open',
                style: ResType.metric.copyWith(
                  color: colors.inkFaint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeedError extends StatelessWidget {
  const _SeedError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ResSpace.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The lesson library did not load',
              style: ResType.heading.copyWith(color: colors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ResSpace.tight),
            Text(
              'Rebuild the curriculum seed:\n'
              'fvm dart run tools/curriculum_build/bin/build.dart',
              style: ResType.metric.copyWith(color: colors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ResSpace.base),
            Text(
              '$error',
              style: ResType.caption.copyWith(color: colors.clip),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The lessons inside a unit, revealed in place.
///
/// Collapsed, this is a zero-height box rather than an absent widget, so
/// [AnimatedSize] has something to animate between and the unit card above it
/// never jumps. Duration comes from [ResMotion.duration], which returns zero
/// under reduced motion — the lessons then appear immediately rather than not
/// at all, which is the rule the rest of the app follows.
/// The lessons inside a unit, fanning out from under it.
///
/// One controller drives every card. That is the whole point: with a controller
/// each, the cards are N animations that happen to start at slightly different
/// times, and it reads as a queue. Driven from one clock with an [Interval] per
/// card, the eye follows a single edge travelling down the list.
///
/// Cards start a little above their resting place and settle downward as they
/// fade in, so they read as coming out from under the unit card that was
/// tapped rather than materialising in a column. Collapsing runs the same
/// clock backwards, and because the intervals are unchanged the last card is
/// the first to leave — the list folds back the way it came out.
///
/// Under reduced motion the controller's duration is zero, so it jumps to the
/// end state: every card at full opacity and no offset. The same widgets, in
/// the same places, without the travel.
class _LessonList extends ConsumerStatefulWidget {
  const _LessonList({
    required this.unit,
    required this.expanded,
    required this.mastery,
    required this.unitIsOpen,
    required this.evaluator,
  });

  final Unit unit;
  final bool expanded;
  final Map<String, Mastery> mastery;
  final bool unitIsOpen;
  final LessonUnlockEvaluator evaluator;

  @override
  ConsumerState<_LessonList> createState() => _LessonListState();
}

class _LessonListState extends ConsumerState<_LessonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fan = AnimationController(
    vsync: this,
    duration: FeedbackChoreography.unitFanTotal,
    value: widget.expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(_LessonList old) {
    super.didUpdateWidget(old);
    if (widget.expanded == old.expanded) return;
    // Read here rather than stored: the setting can change while the app runs.
    _fan.duration = ResMotion.duration(
      context,
      FeedbackChoreography.unitFanTotal,
    );
    widget.expanded ? _fan.forward() : _fan.reverse();
  }

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  /// The slice of the shared clock belonging to card [i].
  ///
  /// Every card gets the **same length** of window, offset by the stagger. The
  /// first attempt ran each from its own start to the end of the timeline,
  /// which shrank the windows from 360ms down to 180ms — the last card
  /// travelling the same ten pixels in half the time as the first. The wave
  /// accelerated down the list and the bottom cards snapped. Equal windows make
  /// it one edge moving at one speed, which is what "fans out" should mean.
  ///
  /// Each card gets the whole remaining window rather than a fixed slice, so
  /// later cards ease over a slightly longer stretch. That is deliberate: equal
  /// slices made the last card snap while the first was still gliding, which
  /// is what a queue looks like.
  Animation<double> _slotFor(int i, int count) {
    final total = FeedbackChoreography.unitFanTotal.inMilliseconds;
    final stagger = FeedbackChoreography.unitFanStagger(count).inMilliseconds;
    final window = total - stagger * (count - 1);

    final begin = (stagger * i) / total;
    final end = (stagger * i + window) / total;

    return CurvedAnimation(
      parent: _fan,
      curve: Interval(begin, end.clamp(0.0, 1.0), curve: ResMotion.enter),
      reverseCurve: Interval(begin, end.clamp(0.0, 1.0), curve: ResMotion.exit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final states = widget.evaluator.evaluate(
      unit: widget.unit,
      unitIsOpen: widget.unitIsOpen,
      mastery: widget.mastery,
    );
    final lessons = widget.unit.lessons;

    return AnimatedBuilder(
      animation: _fan,
      builder: (context, _) => _fan.isDismissed
          // Fully collapsed: gone, not merely clipped to zero height. A
          // SizeTransition keeps its child built, which would leave every
          // lesson in a closed unit reachable by a screen reader.
          ? const SizedBox(width: double.infinity)
          : _fanned(context, states, lessons),
    );
  }

  Widget _fanned(
    BuildContext context,
    Map<String, LessonUnlockState> states,
    List<Lesson> lessons,
  ) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _fan,
        curve: ResMotion.enter,
        reverseCurve: ResMotion.exit,
      ),
      // Anchored to the top so the list grows downward out of the unit card.
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: ResSpace.snug, left: ResSpace.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lessons.length; i++) ...[
              if (i > 0) const SizedBox(height: ResSpace.hair),
              _FannedCard(
                slot: _slotFor(i, lessons.length),
                child: LessonNode(
                  lesson: lessons[i],
                  number: i + 1,
                  mastery:
                      widget.mastery[lessons[i].id] ?? const Mastery.fresh(),
                  unlock: states[lessons[i].id]!,
                  tierColor: context.colors.tier(widget.unit.tierNumber),
                  onTap: () {
                    ref.read(sensoryDirectorProvider).tap();
                    context.push(Routes.lessonPath(lessons[i].id));
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One card's share of the fan.
///
/// Fade and a short downward settle. No scale: a card that grows into place
/// reads as a popup, and these are meant to read as having been underneath the
/// unit all along.
class _FannedCard extends StatelessWidget {
  const _FannedCard({required this.slot, required this.child});

  final Animation<double> slot;
  final Widget child;

  /// How far above its resting place a card starts, in logical pixels.
  ///
  /// Small. At 24 the cards visibly rain down and the eye follows the movement
  /// instead of the list; at 10 the travel is felt without being watched.
  static const _rise = 10.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: slot,
      builder: (context, inner) => Opacity(
        opacity: slot.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -_rise * (1 - slot.value)),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}
