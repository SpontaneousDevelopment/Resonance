import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/curriculum/curriculum.dart';
import '../../domain/scoring/rubric.dart';

/// Fetches the qualitative coaching note for an attempt.
///
/// Sends a transcript and numbers. **Never audio** — the recording does not
/// leave the device, which is why this is a separate call from scoring rather
/// than part of it.
///
/// Every failure path returns null rather than throwing. The note is
/// enrichment: the score, the component breakdown and the marked-up script are
/// already on screen by the time this is called, and a network problem must not
/// turn a finished attempt into an error state.
abstract interface class CoachNoteClient {
  Future<String?> fetch({
    required Lesson lesson,
    required AttemptScore score,
    required String transcript,
  });
}

class HttpCoachNoteClient implements CoachNoteClient {
  HttpCoachNoteClient({
    required this.functionsBaseUrl,
    required this.anonKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 12),
  }) : _http = httpClient ?? http.Client();

  /// e.g. `https://PROJECT.supabase.co/functions/v1`
  final String functionsBaseUrl;
  final String anonKey;
  final Duration timeout;
  final http.Client _http;

  @override
  Future<String?> fetch({
    required Lesson lesson,
    required AttemptScore score,
    required String transcript,
  }) async {
    final measurements = score.measurements;

    final payload = <String, dynamic>{
      'lessonTitle': lesson.title,
      'brief': lesson.brief,
      'script': lesson.script ?? '',
      'transcript': transcript,
      'metrics': {
        'composite': score.composite,
        'clarity': score.component('Clarity')?.score ?? 0,
        'pace': score.component('Pace')?.score ?? 0,
        'plosive': score.component('Plosive control')?.score ?? 0,
        'wordsPerMinute': measurements.wordsPerMinute.round(),
        if (lesson.targetWpmMin != null) 'targetWpmMin': lesson.targetWpmMin,
        if (lesson.targetWpmMax != null) 'targetWpmMax': lesson.targetWpmMax,
      },
      'missedWords': measurements.alignment.missed
          .map((w) => w.expected)
          .whereType<String>()
          .toList(),
    };

    try {
      final response = await _http
          .post(
            Uri.parse('$functionsBaseUrl/coach-note'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $anonKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final note = body['note'] as String?;
      return (note == null || note.trim().isEmpty) ? null : note.trim();
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _http.close();
}

/// Used offline, in tests, and before a backend exists.
class NullCoachNoteClient implements CoachNoteClient {
  const NullCoachNoteClient();

  @override
  Future<String?> fetch({
    required Lesson lesson,
    required AttemptScore score,
    required String transcript,
  }) async => null;
}
