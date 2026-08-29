import 'package:go_router/go_router.dart';

import '../features/skill_tree/skill_tree_screen.dart';

/// Routes.
///
/// Deep-linkable from the start, including lesson ids, because the streak
/// notification in M3 needs to open a specific lesson and retrofitting that is
/// more work than declaring it now.
class Routes {
  const Routes._();

  static const tree = '/';
  static const lesson = '/lesson/:lessonId';

  static String lessonPath(String lessonId) => '/lesson/$lessonId';
}

final router = GoRouter(
  initialLocation: Routes.tree,
  routes: [
    GoRoute(
      path: Routes.tree,
      builder: (context, state) => const SkillTreeScreen(),
    ),
  ],
);
