import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sensory/sensory_director.dart';
import '../../core/sfx/sound_palette.dart';
import '../../domain/curriculum/mastery.dart';
import '../../domain/progress/streak.dart';
import '../../domain/progress/vocal_energy.dart';
import '../../domain/sensory/sensory_cue.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';

/// Plays each cue on demand, labelled.
///
/// Nobody can judge whether a cue feels right by reading its filename, and the
/// placeholder palette has never had a listening pass on a real device. Debug
/// builds only.
///
/// It also lists any audio in `assets/sfx/` that no cue points at — the same
/// class of gap as the tap cue, which shipped with a file and no caller. A
/// stray file here is not a bug, but it should be a deliberate choice rather
/// than something nobody noticed.
class SoundAuditionScreen extends ConsumerStatefulWidget {
  const SoundAuditionScreen({super.key});

  @override
  ConsumerState<SoundAuditionScreen> createState() =>
      _SoundAuditionScreenState();
}

class _SoundAuditionScreenState extends ConsumerState<SoundAuditionScreen> {
  List<String> _unreferenced = const [];
  SoundCue? _lastPlayed;

  @override
  void initState() {
    super.initState();
    _findUnreferencedAssets();
  }

  /// Drops the preloaded players so the next cue re-reads its file.
  ///
  /// The whole point of the audition screen is judging a replacement by ear,
  /// and until this existed that meant killing the app between every swap —
  /// which is long enough to forget what the previous one sounded like.
  Future<void> _reloadFromDisk() async {
    final palette = ref.read(soundPaletteProvider);
    await palette.reloadAssetsFromDisk();
    await _findUnreferencedAssets();
    if (!mounted) return;
    setState(() => _lastPlayed = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sounds dropped. The next play reloads from disk.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _findUnreferencedAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final declared = SoundPalette.assets.values.toSet();
      final onDisk = manifest.listAssets().where(
        (a) => a.startsWith('assets/sfx/') && a.endsWith('.wav'),
      );

      final orphans = onDisk.where((a) => !declared.contains(a)).toList()
        ..sort();
      if (mounted) setState(() => _unreferenced = orphans);
    } catch (_) {
      // Best effort — this is a debug aid, not a feature.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = ref.watch(soundPaletteProvider);
    final director = ref.watch(sensoryDirectorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound palette'),
        actions: [
          IconButton(
            tooltip: 'Reload sounds from disk',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reloadFromDisk,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.gutter),
        children: [
          const SizedBox(height: ResSpace.base),
          Text(
            'Tap to hear each cue. Haptics fire too, so use a phone for the '
            'full impression — macOS has no haptic hardware.',
            style: ResType.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: ResSpace.base),

          if (palette.isDucked)
            Container(
              padding: const EdgeInsets.all(ResSpace.snug),
              decoration: BoxDecoration(
                color: colors.caution.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ResRadius.small),
              ),
              child: Text(
                'The bus is ducked — a take is in progress somewhere, so '
                'nothing will play.',
                style: ResType.caption.copyWith(color: colors.caution),
              ),
            ),

          for (final cue in SoundCue.values)
            _CueRow(
              cue: cue,
              assetPath: SoundPalette.assets[cue] ?? '(no asset declared)',
              isLast: _lastPlayed == cue,
              onPlay: () async {
                setState(() => _lastPlayed = cue);
                // Through the real palette and the real director, so what is
                // heard here is what ships — including the duck gate.
                await director.play([
                  SensoryCue(
                    at: Duration.zero,
                    sound: cue,
                    haptic: _hapticFor(cue),
                  ),
                ]);
              },
            ),

          const SizedBox(height: ResSpace.loose),
          Text(
            'SEQUENCES',
            style: ResType.label.copyWith(color: colors.inkFaint),
          ),
          const SizedBox(height: ResSpace.tight),
          Text(
            'The choreography as it actually fires, with its real timing.',
            style: ResType.caption.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: ResSpace.snug),
          Wrap(
            spacing: ResSpace.tight,
            runSpacing: ResSpace.tight,
            children: [
              _SequenceButton(
                label: 'Levelled up',
                onPlay: () => director.play(
                  director.choreography.forAttempt(
                    score: 88,
                    promotion: _promoted,
                    energyEvent: EnergyEvent.unchanged,
                    streakEvent: StreakEvent.extended,
                  ),
                ),
              ),
              _SequenceButton(
                label: 'Take start / stop',
                onPlay: () async {
                  await director.play(
                    director.choreography.forRecordingStart(),
                  );
                  await Future<void>.delayed(const Duration(milliseconds: 900));
                  await director.play(director.choreography.forRecordingStop());
                },
              ),
            ],
          ),

          if (_unreferenced.isNotEmpty) ...[
            const SizedBox(height: ResSpace.loose),
            Text(
              'IN assets/sfx BUT NOT WIRED TO ANY CUE',
              style: ResType.label.copyWith(color: colors.caution),
            ),
            const SizedBox(height: ResSpace.tight),
            for (final path in _unreferenced)
              Text(path, style: ResType.metric.copyWith(color: colors.caution)),
          ],
          const SizedBox(height: ResSpace.major),
        ],
      ),
    );
  }

  static HapticCue? _hapticFor(SoundCue cue) => switch (cue) {
    SoundCue.tap => HapticCue.tap,
    SoundCue.correct => HapticCue.correct,
    SoundCue.takePassed => HapticCue.takePassed,
    SoundCue.mistake => HapticCue.mistake,
    SoundCue.recordStart => HapticCue.recordStart,
    SoundCue.recordStop => HapticCue.recordStop,
    SoundCue.streakSave => HapticCue.streakSave,
    SoundCue.levelUp => HapticCue.levelUp,
    SoundCue.masteryUnlock => HapticCue.masteryUnlock,
  };
}

class _CueRow extends StatelessWidget {
  const _CueRow({
    required this.cue,
    required this.assetPath,
    required this.isLast,
    required this.onPlay,
  });

  final SoundCue cue;
  final String assetPath;
  final bool isLast;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: ResSpace.tight),
      child: Material(
        color: isLast ? colors.accent.withValues(alpha: 0.08) : colors.surface,
        borderRadius: BorderRadius.circular(ResRadius.medium),
        child: InkWell(
          borderRadius: BorderRadius.circular(ResRadius.medium),
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.all(ResSpace.base),
            child: Row(
              children: [
                Icon(Icons.play_arrow_rounded, color: colors.accent),
                const SizedBox(width: ResSpace.snug),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cue.name,
                        style: ResType.bodyStrong.copyWith(color: colors.ink),
                      ),
                      Text(
                        assetPath,
                        style: ResType.metric.copyWith(
                          color: colors.inkFaint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SequenceButton extends StatelessWidget {
  const _SequenceButton({required this.label, required this.onPlay});

  final String label;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPlay, child: Text(label));
}

const _promoted = PromotionResult(
  before: MasteryLevel.bronze,
  after: MasteryLevel.silver,
);

/// Debug builds only.
bool get soundAuditionAvailable => kDebugMode;
