import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../debug/sound_audition_screen.dart';

import '../../core/progress/progress_repository.dart';
import '../../domain/progress/vocal_energy.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';

/// Streak, today's XP and Vocal Energy, above the tree.
///
/// Deliberately small and unanimated. These numbers are the reason a habit app
/// gets opened, and they earn that by being *there* — a celebratory treatment
/// on the home screen would make every launch feel like a reward ceremony and
/// stop meaning anything by the third day.
class ProgressHeader extends ConsumerWidget {
  const ProgressHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final streak = ref.watch(streakProvider).value;
    final energy = ref.watch(energyProvider).value;
    final xp = ref.watch(xpTodayProvider).value ?? 0;

    return Row(
      spacing: ResSpace.loose,
      children: [
        _Metric(
          label: 'STREAK',
          value: '${streak?.currentStreak ?? 0}',
          suffix: (streak?.currentStreak ?? 0) == 1 ? 'day' : 'days',
          tone: (streak?.currentStreak ?? 0) > 0
              ? colors.tier3
              : colors.inkFaint,
        ),
        _Metric(
          label: 'TODAY',
          value: '$xp',
          suffix: 'xp',
          tone: xp > 0 ? colors.accent : colors.inkFaint,
        ),
        _EnergyMeter(energy: energy ?? const VocalEnergy.full()),
        // Debug builds only. The placeholder palette still needs a listening
        // pass on a real device, and there is no other way in on desktop.
        if (soundAuditionAvailable) ...[
          const Spacer(),
          IconButton(
            tooltip: 'Audition sounds',
            icon: const Icon(Icons.music_note_outlined, size: 18),
            onPressed: () => context.push(Routes.soundAudition),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.suffix,
    required this.tone,
  });

  final String label;
  final String value;
  final String suffix;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ResType.label.copyWith(color: colors.inkFaint)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: ResType.metric.copyWith(color: tone, fontSize: 20),
            ),
            const SizedBox(width: 3),
            Text(
              suffix,
              style: ResType.caption.copyWith(color: colors.inkFaint),
            ),
          ],
        ),
      ],
    );
  }
}

/// Five discrete bars, matching the meter's actual granularity.
///
/// Not a continuous gauge — energy moves in whole bars, and a smooth bar would
/// imply a precision the rule does not have.
class _EnergyMeter extends StatelessWidget {
  const _EnergyMeter({required this.energy});

  final VocalEnergy energy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = energy.isEmpty ? colors.caution : colors.signal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VOICE', style: ResType.label.copyWith(color: colors.inkFaint)),
        const SizedBox(height: 6),
        Semantics(
          label: '${energy.bars} of ${VocalEnergy.maxBars} vocal energy',
          child: Row(
            spacing: 3,
            children: [
              for (var i = 0; i < VocalEnergy.maxBars; i++)
                Container(
                  width: 9,
                  height: 14,
                  decoration: BoxDecoration(
                    color: i < energy.bars ? tone : Colors.transparent,
                    border: Border.all(
                      color: i < energy.bars ? tone : colors.rule,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
