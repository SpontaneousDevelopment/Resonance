import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../domain/curriculum/curriculum.dart';
import '../../../ui/tokens/spacing.dart';
import '../../../ui/tokens/theme.dart';
import '../../../ui/tokens/typography.dart';

/// Plays a third-party reference clip through the publisher's own embedded
/// player, clipped to the lesson's in/out points.
///
/// Nothing is downloaded, cached or stored — this widget holds a video id and
/// two timestamps, and the publisher serves the media. That is the whole design
/// of the listen-and-analyse lesson type.
///
/// **Platform support**, verified rather than assumed: `webview_flutter` 4.14
/// carries an endorsed macOS implementation via `webview_flutter_wkwebview`
/// 3.26, so all three targets share this widget. macOS additionally requires
/// the `com.apple.security.network.client` entitlement — without it the
/// WebView loads a blank page and reports no error, which is a very slow bug to
/// find. See `macos/Runner/*.entitlements`.
class EmbedReferencePlayer extends StatefulWidget {
  const EmbedReferencePlayer({
    super.key,
    required this.reference,
    this.onReady,
  });

  final LessonReference reference;
  final VoidCallback? onReady;

  @override
  State<EmbedReferencePlayer> createState() => _EmbedReferencePlayerState();
}

class _EmbedReferencePlayerState extends State<EmbedReferencePlayer> {
  late final YoutubePlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final ref = widget.reference;
    assert(
      ref.source == ReferenceSource.embed && ref.videoId != null,
      'EmbedReferencePlayer requires an embed reference with a video id',
    );

    try {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: ref.videoId!,
        startSeconds: ref.startSeconds?.toDouble(),
        endSeconds: ref.endSeconds?.toDouble(),
        autoPlay: false,
        params: const YoutubePlayerParams(
          // The lesson supplies its own framing; the player should be a clip,
          // not a portal into more videos.
          showControls: true,
          showFullscreenButton: false,
          showVideoAnnotations: false,
          enableCaption: true,
          strictRelatedVideos: true,
        ),
      );
    } catch (error) {
      _error = error;
    }
  }

  @override
  void dispose() {
    if (_error == null) _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ref = widget.reference;

    if (_error != null) {
      return _Unavailable(message: '$_error');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(ResRadius.medium),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
          ),
        ),
        const SizedBox(height: ResSpace.tight),
        // Provenance is always visible. A user studying a performance should
        // know whose it is without having to ask.
        Row(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 14,
              color: colors.inkFaint,
            ),
            const SizedBox(width: ResSpace.hair),
            Expanded(
              child: Text(
                ref.attribution ?? 'Streamed from the publisher',
                style: ResType.caption.copyWith(color: colors.inkFaint),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(ResSpace.base),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ResRadius.medium),
        border: Border.all(color: colors.ruleSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This clip will not play here',
            style: ResType.bodyStrong.copyWith(color: colors.ink),
          ),
          const SizedBox(height: ResSpace.hair),
          Text(
            'The rest of the lesson still works — the listening prompt is below.',
            style: ResType.caption.copyWith(color: colors.inkMuted),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: ResSpace.tight),
            Text(message, style: ResType.metric.copyWith(color: colors.clip)),
          ],
        ],
      ),
    );
  }
}
