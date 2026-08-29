import 'package:flutter/material.dart';

import '../../../domain/curriculum/mastery.dart';
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
    this.onRetry,
    this.onContinue,
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

  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

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
              Text(
                '${score.composite}',
                style: ResType.metricLarge.copyWith(color: colors.ink),
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
