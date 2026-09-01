import 'package:flutter/material.dart';

import '../../../core/progress/progress_repository.dart';
import '../../../domain/curriculum/mastery.dart';
import '../../../domain/progress/streak.dart';
import '../../../domain/progress/vocal_energy.dart';
import '../../../domain/scoring/rubric.dart';
import '../../../domain/scoring/transcript_alignment.dart';
import '../../../ui/tokens/motion.dart';
import '../../../ui/tokens/spacing.dart';
import '../../../ui/tokens/theme.dart';
import '../../../ui/tokens/typography.dart';
import '../../skill_tree/mastery_ring.dart';

/// The screen that decides whether the loop is worth repeating.
///
/// Three rules shape it:
///
/// * **The number arrives instantly.** Everything here comes from on-device
///   measurement, so it renders the moment the take stops. The coach note
///   streams in afterwards and its absence never blocks anything.
/// * **Show the words, not just the score.** "Clarity 78" teaches nothing;
///   the script with the lost words marked teaches immediately.
/// * **Say what to do next.** Every component carries one specific, actionable
///   line, which is why [ScoreComponent.detail] exists at all.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({
    super.key,
    required this.lessonTitle,
    required this.script,
    required this.score,
    required this.promotion,
    this.coachNote,
    this.coachNotePending = false,
    this.clarityUnavailable = false,
    this.outcome,
    this.onRetry,
    this.onContinue,
    this.onTakeFive,
  });

  final String lessonTitle;
  final String script;
  final AttemptScore score;

  /// What this attempt did to the ladder.
  final PromotionResult promotion;

  /// The LLM note, once it lands.
  final String? coachNote;
  final bool coachNotePending;

  /// True when no transcript could be obtained — no recogniser, no permission,
  /// or offline on a device that needs the network for it. The attempt still
  /// scores on pace and mic technique, and saying so is better than letting the
  /// user assume the number means what it usually means.
  final bool clarityUnavailable;

  /// What this attempt changed — streak, XP, energy. Null before it persists.
  final SessionOutcome? outcome;

  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

  /// Opens the rest exercise. Offered, never forced.
  final VoidCallback? onTakeFive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: context.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: ResSpace.loose),
                    _Headline(score: score, promotion: promotion),
                    if (clarityUnavailable) ...[
                      const SizedBox(height: ResSpace.base),
                      _ClarityUnavailableNotice(),
                    ],
                    const SizedBox(height: ResSpace.loose),
                    if (outcome != null) ...[
                      _OutcomeStrip(outcome: outcome!),
                      const SizedBox(height: ResSpace.base),
                    ],
                    if (outcome?.energy.isEmpty ?? false) ...[
                      _RestOffer(onTakeFive: onTakeFive),
                      const SizedBox(height: ResSpace.base),
                    ],
                    _CoachNote(note: coachNote, pending: coachNotePending),
                    const SizedBox(height: ResSpace.loose),
                    for (final component in score.components)
                      if (component.weight > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: ResSpace.snug),
                          child: _ComponentRow(component: component),
                        ),
                    const SizedBox(height: ResSpace.base),
                    Text(
                      'YOUR READ',
                      style: ResType.label.copyWith(color: colors.inkFaint),
                    ),
                    const SizedBox(height: ResSpace.tight),
                    _MarkedScript(
                      script: script,
                      alignment: score.measurements.alignment,
                    ),
                    const SizedBox(height: ResSpace.loose),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                ResSpace.tight,
                context.gutter,
                ResSpace.base,
              ),
              child: Row(
                spacing: ResSpace.snug,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Again'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: onContinue,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.score, required this.promotion});

  final AttemptScore score;
  final PromotionResult promotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MasteryRing(level: promotion.after, color: colors.accent, size: 64),
        const SizedBox(width: ResSpace.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                // The number is the first thing a sighted user sees and the
                // last thing a screen reader can make sense of unannotated:
                // "78" alone says nothing about what it measures, what it is
                // out of, or what happened to the level.
                header: true,
                label:
                    'Score ${score.composite} out of 100. '
                    '${_verdict(promotion)}. '
                    'Mastery ${promotion.after.label}.',
                excludeSemantics: true,
                child: Text(
                  '${score.composite}',
                  style: ResType.metricLarge.copyWith(color: colors.ink),
                ),
              ),
              const SizedBox(height: ResSpace.hair),
              Text(
                _verdict(promotion),
                style: ResType.bodyStrong.copyWith(
                  color: promotion.promoted
                      ? colors.accentInk
                      : colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The blocked cases are where this screen earns its keep. Being told "you
  /// already levelled this up today, come back tomorrow" has to read as the app
  /// protecting your progress, not withholding it.
  static String _verdict(PromotionResult promotion) =>
      switch (promotion.block) {
        null => 'Levelled up to ${promotion.after.label}.',
        PromotionBlock.alreadyPromotedToday =>
          'Nice one. You have already levelled this up today — voice settles '
              'overnight, so the next rung opens tomorrow.',
        PromotionBlock.scoreTooLow =>
          'Not quite ${promotion.before.next?.label ?? "the next level"} yet. '
              'Have another go.',
        PromotionBlock.atCeiling => 'Still at Master. Keeping it sharp.',
      };
}

/// Streak, XP and energy in one line.
class _OutcomeStrip extends StatelessWidget {
  const _OutcomeStrip({required this.outcome});

  final SessionOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final streak = outcome.streak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: ResSpace.loose,
          children: [
            _Stat(
              label: 'STREAK',
              value: '${streak.currentStreak}',
              tone: colors.tier3,
            ),
            _Stat(
              label: 'XP',
              value: '+${outcome.xpAwarded}',
              tone: colors.accent,
            ),
            _Stat(
              label: 'ENERGY',
              value: '${outcome.energy.bars}/${VocalEnergy.maxBars}',
              tone: outcome.energy.isEmpty ? colors.caution : colors.inkMuted,
            ),
          ],
        ),
        // A freeze is spent silently at the time; this is where the user finds
        // out it happened. Saying nothing would make the streak look like it
        // survived a missed day by accident.
        if (streak.event == StreakEvent.savedByFreeze) ...[
          const SizedBox(height: ResSpace.tight),
          Text(
            'You missed yesterday — a streak freeze covered it. '
            '${streak.freezesRemaining} left.',
            style: ResType.caption.copyWith(color: colors.tier3),
          ),
        ],
        if (streak.event == StreakEvent.reset) ...[
          const SizedBox(height: ResSpace.tight),
          Text(
            'Your streak restarted. Longest so far: ${streak.longestStreak} days.',
            style: ResType.caption.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ResType.label.copyWith(color: colors.inkFaint)),
        const SizedBox(height: 2),
        Text(value, style: ResType.metric.copyWith(color: tone, fontSize: 18)),
      ],
    );
  }
}

/// Shown when energy runs out. An offer — the Continue button is still right
/// there, and nothing about this screen prevents another attempt.
class _RestOffer extends StatelessWidget {
  const _RestOffer({required this.onTakeFive});

  final VoidCallback? onTakeFive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ResSpace.base),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ResRadius.medium),
        border: Border.all(color: colors.caution.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your voice has been working hard',
            style: ResType.bodyStrong.copyWith(color: colors.ink),
          ),
          const SizedBox(height: ResSpace.hair),
          Text(
            'Ninety seconds of breathing and a quiet hum will do more for your '
            'next take than another attempt would. You can carry on if you '
            'would rather.',
            style: ResType.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: ResSpace.snug),
          FilledButton(
            onPressed: onTakeFive,
            style: FilledButton.styleFrom(backgroundColor: colors.caution),
            child: const Text('Take five'),
          ),
        ],
      ),
    );
  }
}

class _ClarityUnavailableNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ResSpace.snug),
      decoration: BoxDecoration(
        color: colors.caution.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ResRadius.small),
        border: Border.all(color: colors.caution.withValues(alpha: 0.35)),
      ),
      child: Text(
        'We could not hear your words this time, so this score covers pace and '
        'mic technique only.',
        style: ResType.caption.copyWith(color: colors.caution),
      ),
    );
  }
}

class _CoachNote extends StatelessWidget {
  const _CoachNote({required this.note, required this.pending});

  final String? note;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (note == null && !pending) return const SizedBox.shrink();

    return AnimatedSize(
      duration: ResMotion.duration(context, ResMotion.control),
      alignment: Alignment.topLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ResSpace.base),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(ResRadius.medium),
          border: Border.all(color: colors.ruleSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A label rather than a coloured rail down one side: Flutter cannot
            // paint a rounded border whose sides differ in colour, and naming
            // the voice says whose note this is more plainly anyway.
            Text('COACH', style: ResType.label.copyWith(color: colors.accent)),
            const SizedBox(height: ResSpace.tight),
            if (pending)
              Row(
                spacing: ResSpace.snug,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colors.inkFaint,
                    ),
                  ),
                  Text(
                    'Listening back…',
                    style: ResType.caption.copyWith(color: colors.inkFaint),
                  ),
                ],
              )
            else
              Text(note!, style: ResType.body.copyWith(color: colors.ink)),
          ],
        ),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final ScoreComponent component;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = switch (component.score) {
      >= 85 => colors.signal,
      >= 65 => colors.caution,
      _ => colors.clip,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                component.label,
                style: ResType.bodyStrong.copyWith(color: colors.ink),
              ),
            ),
            Text(
              '${component.score}',
              style: ResType.metric.copyWith(color: tone, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: ResSpace.hair),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: component.score / 100),
            duration: ResMotion.duration(context, ResMotion.celebrate),
            curve: ResMotion.enter,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: colors.ruleSoft,
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
        ),
        if (component.detail != null) ...[
          const SizedBox(height: ResSpace.hair),
          Text(
            component.detail!,
            style: ResType.caption.copyWith(color: colors.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// The script with the words that did not survive marked in place.
///
/// This is the part that actually teaches. A percentage tells you that you were
/// unclear; seeing "batch" struck through with "bat" underneath tells you that
/// you dropped a final consonant, which is a thing you can fix on the next take.
class _MarkedScript extends StatelessWidget {
  const _MarkedScript({required this.script, required this.alignment});

  final String script;
  final TranscriptAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final problems = <int, AlignedWord>{
      for (final word in alignment.missed)
        if (word.expectedIndex != null) word.expectedIndex!: word,
    };

    final originalWords = script.split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);

    // The alignment indexes normalised words, which can differ in count from
    // the display words once contractions expand. When they diverge, fall back
    // to plain text rather than marking the wrong word — a confident wrong
    // highlight is worse than none.
    final normalisedCount = TextNormaliser.words(script).length;
    final canMark = normalisedCount == originalWords.length;

    if (!canMark) {
      return Text(script, style: ResType.script.copyWith(color: colors.ink));
    }

    return RichText(
      text: TextSpan(
        style: ResType.script.copyWith(color: colors.ink),
        children: [
          for (var i = 0; i < originalWords.length; i++)
            TextSpan(
              text:
                  '${originalWords[i]}${i == originalWords.length - 1 ? '' : ' '}',
              style: problems.containsKey(i)
                  ? ResType.script.copyWith(
                      color: colors.clip,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.clip,
                      decorationStyle: TextDecorationStyle.wavy,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
