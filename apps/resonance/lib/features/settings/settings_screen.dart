import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/account_service.dart';
import '../../core/net/supabase_config.dart';
import '../../core/sync/sync_settings.dart';
import '../../ui/tokens/spacing.dart';
import '../../ui/tokens/theme.dart';
import '../../ui/tokens/typography.dart';

/// Settings.
///
/// Sign-in lives here rather than in onboarding on purpose. The app is
/// anonymous-first: asking for an email before someone has read a single line
/// aloud is asking them to commit before they know whether they want to, and
/// nothing about the product needs it.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _email = TextEditingController();
  String? _notice;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'That does not look like an email address.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      await ref.read(accountServiceProvider).sendMagicLink(email);
      if (mounted) {
        setState(
          () => _notice =
              'Check $email for a link. It signs you in — '
              'there is no password to remember.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not send the link: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Rebuilds when a magic-link callback lands while this screen is open.
    ref.watch(authStateProvider);
    final account = ref.watch(accountServiceProvider);
    final settings = ref.watch(syncSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.gutter),
        children: [
          const SizedBox(height: ResSpace.base),

          Text(
            'ACCOUNT',
            style: ResType.label.copyWith(color: colors.inkFaint),
          ),
          const SizedBox(height: ResSpace.tight),

          if (!SupabaseConfig.isConfigured)
            _Note(
              'This build has no backend configured, so accounts are '
              'unavailable. Everything else works exactly as it does with one.',
              tone: colors.inkMuted,
            )
          else if (account.isSignedIn)
            _SignedIn(
              email: account.currentUser?.email ?? 'your account',
              onSignOut: () async {
                await ref.read(accountServiceProvider).signOut();
                if (mounted) {
                  setState(() {
                    _notice =
                        'Signed out. Your practice on this device is '
                        'untouched.';
                  });
                }
              },
            )
          else
            _SignIn(controller: _email, busy: _busy, onSend: _sendLink),

          if (_notice != null) ...[
            const SizedBox(height: ResSpace.snug),
            _Note(_notice!, tone: colors.accentInk),
          ],
          if (_error != null) ...[
            const SizedBox(height: ResSpace.snug),
            _Note(_error!, tone: colors.clip),
          ],

          const SizedBox(height: ResSpace.section),
          Text('SYNC', style: ResType.label.copyWith(color: colors.inkFaint)),
          const SizedBox(height: ResSpace.tight),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.syncOnCellular,
            onChanged: (value) => ref
                .read(syncSettingsProvider.notifier)
                .setSyncOnCellular(value),
            title: Text(
              'Sync progress on mobile data',
              style: ResType.bodyStrong.copyWith(color: colors.ink),
            ),
            subtitle: Text(
              'Scores, streaks and progress only — a few hundred bytes a '
              'session. Recordings are never uploaded.',
              style: ResType.caption.copyWith(color: colors.inkMuted),
            ),
          ),

          const SizedBox(height: ResSpace.section),
          Text(
            'YOUR DATA',
            style: ResType.label.copyWith(color: colors.inkFaint),
          ),
          const SizedBox(height: ResSpace.tight),
          _DeleteEverything(
            isSignedIn: account.isSignedIn,
            onDeleted: () {
              if (mounted) {
                setState(() => _notice = 'Everything has been deleted.');
              }
            },
          ),
          const SizedBox(height: ResSpace.major),
        ],
      ),
    );
  }
}

class _SignIn extends StatelessWidget {
  const _SignIn({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'An account keeps your progress if you change device. Everything '
          'works without one — this only adds syncing.',
          style: ResType.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: ResSpace.snug),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: ResSpace.snug),
        FilledButton(
          onPressed: busy ? null : onSend,
          child: Text(busy ? 'Sending…' : 'Email me a link'),
        ),
      ],
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.email, required this.onSignOut});

  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: ResType.bodyStrong.copyWith(color: colors.ink),
              ),
              Text(
                'Progress syncs to your account.',
                style: ResType.caption.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onSignOut, child: const Text('Sign out')),
      ],
    );
  }
}

/// Irreversible, and presented as such.
///
/// Two steps rather than one, and the second requires typing the word — a
/// confirm button next to a destructive action is exactly what a person taps
/// by reflex. This deletes the account too, not just its contents.
class _DeleteEverything extends ConsumerStatefulWidget {
  const _DeleteEverything({required this.isSignedIn, required this.onDeleted});

  final bool isSignedIn;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_DeleteEverything> createState() => _DeleteEverythingState();
}

class _DeleteEverythingState extends ConsumerState<_DeleteEverything> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isSignedIn
              ? 'Deletes your practice history on this device and on the '
                    'server, and closes your account. This cannot be undone.'
              : 'Deletes your practice history on this device. This cannot be '
                    'undone.',
          style: ResType.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: ResSpace.snug),
        OutlinedButton(
          onPressed: () => _confirm(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.clip,
            side: BorderSide(color: colors.clip),
          ),
          child: const Text('Delete everything'),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(isSignedIn: widget.isSignedIn),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref.read(accountServiceProvider).deleteEverything();
      if (mounted) widget.onDeleted();
    } catch (error) {
      if (!mounted) return;
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nothing was deleted'),
          content: Text('$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.isSignedIn});

  final bool isSignedIn;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _typed = TextEditingController();
  static const _word = 'DELETE';

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _typed.text.trim().toUpperCase() == _word;
    return AlertDialog(
      title: const Text('Delete everything?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isSignedIn
                ? 'Your recordings, scores, streaks and account will be '
                      'permanently removed. There is no way to get them back, '
                      'and no copy is kept.'
                : 'Your recordings, scores and streaks will be permanently '
                      'removed from this device. There is no way to get them '
                      'back.',
          ),
          const SizedBox(height: ResSpace.base),
          const Text('Type DELETE to confirm.'),
          const SizedBox(height: ResSpace.tight),
          TextField(
            controller: _typed,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my data'),
        ),
        FilledButton(
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete everything'),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.message, {required this.tone});

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ResSpace.snug),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(ResRadius.small),
      border: Border.all(color: tone.withValues(alpha: 0.3)),
    ),
    child: Text(message, style: ResType.caption.copyWith(color: tone)),
  );
}
