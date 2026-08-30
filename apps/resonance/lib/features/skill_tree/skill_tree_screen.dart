import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/curriculum_repository.dart';
import '../../core/progress/progress_repository.dart';
import '../../domain/curriculum/unlock.dart';
import 'progress_header.dart';
import '../../domain/curriculum/curriculum.dart';
import '../../domain/curriculum/mastery.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';
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

class _Tree extends StatelessWidget {
  const _Tree({required this.curriculum, required this.mastery});

  final Curriculum curriculum;
  final Map<String, Mastery> mastery;

  static const _evaluator = UnlockEvaluator();

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
                final unlock = unlockStates[unit.id];
                final unitMastery = _bestMasteryIn(unit);
                return UnitNode(
                  unit: unit,
                  // Until progress persistence lands in M3, the first authored
                  // unit is open and everything else reads as locked. This is
                  // scaffolding, not the unlock rule — that lives in
                  // domain/curriculum/mastery.dart and is already tested.
                  mastery: unitMastery,
                  isUnlocked: unlock?.isOpen ?? false,
                  onTap: (unlock?.isOpen ?? false)
                      ? () => context.push(
                          Routes.lessonPath(unit.lessons.first.id),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

extension on _Tree {
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
