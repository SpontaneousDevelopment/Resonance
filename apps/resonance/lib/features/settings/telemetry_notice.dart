import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/telemetry/telemetry_settings.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';

/// Shown once, on the first launch of an internal or TestFlight build, before
/// any crash report can be sent.
///
/// This exists because "we told the testers" is not a thing you can point at.
/// A line in release notes is a notice nobody has to see; a gate someone has to
/// dismiss is one they did. Until [TelemetrySettings.noticeSeen] is true,
/// `maySend` is false and the reporter drops everything, so this screen is
/// load-bearing rather than informational.
///
/// Store builds never see it — there, telemetry is off until someone turns it
/// on in settings, which is its own act of consent.
class TelemetryNotice extends ConsumerWidget {
  const TelemetryNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifier = ref.read(telemetrySettingsProvider.notifier);

    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: context.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS IS A TEST BUILD',
                    style: ResType.label.copyWith(color: colors.inkFaint),
                  ),
                  const SizedBox(height: ResSpace.tight),
                  Text(
                    'It sends crash reports.',
                    style: ResType.title.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: ResSpace.base),
                  Text(
                    'If the app crashes, it sends the error and where it '
                    'happened, plus your device model and OS version. That is '
                    'the whole list.',
                    style: ResType.body.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: ResSpace.snug),
                  Text(
                    'It does not send recordings, transcripts, scores, your '
                    'practice history, or your email. It does not track what '
                    'you tap or how long you use the app, and it sends nothing '
                    'at all unless something breaks.',
                    style: ResType.body.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: ResSpace.snug),
                  Text(
                    'You can turn this off now or at any time in Settings.',
                    style: ResType.body.copyWith(color: colors.inkMuted),
                  ),
                  const SizedBox(height: ResSpace.loose),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          notifier.acknowledgeNotice(enabled: true),
                      child: const Text('Send crash reports'),
                    ),
                  ),
                  const SizedBox(height: ResSpace.snug),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          notifier.acknowledgeNotice(enabled: false),
                      child: const Text('Not this time'),
                    ),
                  ),
                  const SizedBox(height: ResSpace.base),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
