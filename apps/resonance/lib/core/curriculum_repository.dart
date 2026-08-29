import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/curriculum/curriculum.dart';

/// Loads the compiled curriculum seed from the app bundle.
///
/// The seed ships with the binary, so this never touches the network and never
/// fails in a way the user can cause. A malformed seed is a build-time mistake
/// that should have been caught by `tools/curriculum_build`, so it throws
/// rather than degrading — better a loud crash in development than a silently
/// empty tree in production.
class CurriculumRepository {
  const CurriculumRepository();

  static const _seedPath = 'assets/seed/curriculum.json';

  Future<Curriculum> load() async {
    final raw = await rootBundle.loadString(_seedPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Curriculum.fromJson(json);
  }
}

final curriculumRepositoryProvider = Provider<CurriculumRepository>(
  (ref) => const CurriculumRepository(),
);

/// The whole tree. Loaded once and cached for the process lifetime — it is a
/// few hundred kilobytes of immutable data and re-reading it would be waste.
final curriculumProvider = FutureProvider<Curriculum>((ref) async {
  return ref.watch(curriculumRepositoryProvider).load();
});
