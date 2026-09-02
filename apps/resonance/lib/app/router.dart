import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/curriculum_repository.dart';
import '../domain/sensory/sensory_cue.dart';
import '../features/debug/sound_audition_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/skill_tree/skill_tree_screen.dart';
import '../ui/tokens/motion.dart';
import '../ui/tokens/spacing.dart';
import '../ui/tokens/theme.dart';
import '../ui/tokens/typography.dart';

/// Routes.
///
/// Lessons are addressed by id and resolved from the bundled curriculum, so a
/// deep link from a streak notification opens the right lesson without the
/// sender having to carry its content.
class Routes {
  const Routes._();

  static const tree = '/';

  static String lessonPath(String lessonId) => '/lesson/$lessonId';

  /// Debug builds only — see [soundAuditionAvailable].
  static const soundAudition = '/debug/sounds';
  static const settings = '/settings';
}

/// Builds a router.
///
/// A factory rather than a top-level `final`, because a `GoRouter` holds
/// mutable navigation state. A single global instance keeps its location across
/// hot restarts and across integration tests — the second test starts wherever
/// the first one left off, which produces failures that look like missing
/// widgets and are actually stale routes.
GoRouter createRouter() =>
    GoRouter(initialLocation: Routes.tree, routes: _routes);

/// One router per app instance.
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});

final List<RouteBase> _routes = [
  GoRoute(
    path: Routes.tree,
    builder: (context, state) => const SkillTreeScreen(),
    routes: [
      if (soundAuditionAvailable)
        GoRoute(
          path: 'debug/sounds',
          builder: (context, state) => const SoundAuditionScreen(),
        ),
      GoRoute(
        path: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: 'lesson/:lessonId',
        // A modal entrance: the lesson rises from the bottom over the tree, and
        // leaves the way it came. The gesture is the point — a lesson is
        // something you step into and back out of, not somewhere you navigate
        // to, and the reverse of this transition is what dismissing the
        // feedback screen resolves into.
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: ResMotion.duration(
            context,
            FeedbackChoreography.lessonEnter,
          ),
          reverseTransitionDuration: ResMotion.duration(
            context,
            FeedbackChoreography.lessonExit,
          ),
          child: _LessonRoute(lessonId: state.pathParameters['lessonId']!),
          transitionsBuilder: (context, animation, secondary, child) {
            // easeOutCubic in, easeInCubic out: it decelerates into place and
            // gathers speed on the way down, which is what weight does. A
            // linear tween reads as a panel being dragged by the app rather
            // than a thing with mass.
            final curved = CurvedAnimation(
              parent: animation,
              curve: ResMotion.enter,
              reverseCurve: ResMotion.exit,
            );
            return SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            );
          },
        ),
      ),
    ],
  ),
];

/// Resolves a lesson id against the curriculum before building the screen.
class _LessonRoute extends ConsumerWidget {
  const _LessonRoute({required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = ref.watch(curriculumProvider);

    return curriculum.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _Missing(message: '$error'),
      data: (data) {
        final lesson = data.lessonById(lessonId);
        if (lesson == null) {
          return _Missing(
            message: 'That lesson is not in this version of the app.',
          );
        }
        return LessonScreen(lesson: lesson);
      },
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ResSpace.section),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: ResType.body.copyWith(color: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}
