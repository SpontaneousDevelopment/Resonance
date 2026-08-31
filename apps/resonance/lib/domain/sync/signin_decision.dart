/// What signing in should do with progress already on the device.
///
/// Deliberately not a merge engine. The common case — a brand-new account with
/// no remote history — is not a merge at all: the local progress simply becomes
/// the account's starting state. Building general two-way reconciliation for
/// that would be inventing a problem.
///
/// The rare case, signing into an account that already has its own history from
/// a device that also has unrelated anonymous progress, is not resolved
/// automatically. Both sides are real work by a real person and a machine
/// cannot know which they meant to keep, so it is surfaced and they choose.
///
/// The one thing that must never happen is silently discarding local progress
/// as a side effect of signing in.
library;

/// How much history a side holds. Enough to decide, not enough to merge with.
class ProgressSummary {
  const ProgressSummary({
    required this.lessonsAttempted,
    required this.totalXp,
    required this.currentStreak,
    this.lastPracticedOn,
  });

  const ProgressSummary.empty()
    : lessonsAttempted = 0,
      totalXp = 0,
      currentStreak = 0,
      lastPracticedOn = null;

  final int lessonsAttempted;
  final int totalXp;
  final int currentStreak;
  final DateTime? lastPracticedOn;

  /// Whether there is anything here worth protecting.
  ///
  /// Attempts rather than XP: a user who practised and scored nothing still did
  /// the work, and losing it would feel identical to losing a good session.
  bool get hasHistory => lessonsAttempted > 0;
}

enum SignInOutcome {
  /// No local progress. Sign in and pull the account's history down.
  adoptRemote,

  /// Local progress, empty account. The account starts as this device — the
  /// common case, and not a merge.
  adoptLocal,

  /// Both sides hold history. The user decides; nothing happens until they do.
  needsChoice,

  /// Neither side has anything. Sign in and carry on.
  nothingToCarry,
}

class SignInDecision {
  const SignInDecision({
    required this.outcome,
    required this.local,
    required this.remote,
  });

  final SignInOutcome outcome;
  final ProgressSummary local;
  final ProgressSummary remote;

  /// Whether the app must stop and ask before doing anything.
  bool get requiresUserChoice => outcome == SignInOutcome.needsChoice;

  /// Whether local progress would be lost if the user picked the remote side.
  /// Drives the wording of the prompt, which has to name what is at stake.
  bool get localAtRisk => local.hasHistory;

  static SignInDecision evaluate({
    required ProgressSummary local,
    required ProgressSummary remote,
  }) {
    if (!local.hasHistory && !remote.hasHistory) {
      return SignInDecision(
        outcome: SignInOutcome.nothingToCarry,
        local: local,
        remote: remote,
      );
    }
    if (local.hasHistory && !remote.hasHistory) {
      return SignInDecision(
        outcome: SignInOutcome.adoptLocal,
        local: local,
        remote: remote,
      );
    }
    if (!local.hasHistory && remote.hasHistory) {
      return SignInDecision(
        outcome: SignInOutcome.adoptRemote,
        local: local,
        remote: remote,
      );
    }
    return SignInDecision(
      outcome: SignInOutcome.needsChoice,
      local: local,
      remote: remote,
    );
  }
}

/// What the user picked when both sides held history.
enum ProgressChoice {
  /// Keep what is on this device; the account's history is replaced.
  keepLocal,

  /// Keep the account's history; this device's anonymous progress is dropped.
  ///
  /// Only ever reachable by explicit choice — never a default, never a
  /// side effect.
  keepRemote,
}
