/// Aligns what the speech recogniser heard against the script the user was
/// meant to read.
///
/// This is the foundation of every clarity score in the app, and the reason
/// scoring can be honest about *which words* were dropped rather than just
/// producing a percentage. "You lost the T on 'packed'" is a coaching note;
/// "clarity: 78" is not.
///
/// Pure Dart, no Flutter, no I/O — so the rubric can be regression-tested
/// against a fixture set of real transcripts as the weights are tuned.
library;

/// What happened to one word.
enum AlignmentOp {
  /// Said as written.
  match,

  /// Said, but heard as a different word. Usually an articulation problem:
  /// "batch" heard as "bat" is a dropped final consonant.
  substitution,

  /// In the script, not in the transcript. Either skipped or too indistinct to
  /// register at all.
  omission,

  /// In the transcript, not in the script. A stumble, a repeated word, a
  /// filler, or a restart.
  insertion,
}

/// One aligned position.
class AlignedWord {
  const AlignedWord({
    required this.op,
    this.expected,
    this.heard,
    this.expectedIndex,
    this.confidence,
  });

  final AlignmentOp op;

  /// The script word, normalised. Null for an insertion.
  final String? expected;

  /// The transcribed word, normalised. Null for an omission.
  final String? heard;

  /// Position in the original script, for highlighting the passage.
  final int? expectedIndex;

  /// Recogniser confidence for [heard], when the platform supplies one.
  final double? confidence;

  bool get isCorrect => op == AlignmentOp.match;

  @override
  String toString() => switch (op) {
    AlignmentOp.match => 'ok:$expected',
    AlignmentOp.substitution => '$expected→$heard',
    AlignmentOp.omission => '-$expected',
    AlignmentOp.insertion => '+$heard',
  };
}

/// The result of aligning a transcript to a script.
///
/// Named for the file rather than just `Alignment`, which would collide with
/// Flutter's own `Alignment` at every UI call site.
class TranscriptAlignment {
  const TranscriptAlignment({required this.words, required this.expectedCount});

  final List<AlignedWord> words;

  /// Words in the script. The denominator for accuracy.
  final int expectedCount;

  int get matches => words.where((w) => w.op == AlignmentOp.match).length;
  int get substitutions =>
      words.where((w) => w.op == AlignmentOp.substitution).length;
  int get omissions => words.where((w) => w.op == AlignmentOp.omission).length;
  int get insertions =>
      words.where((w) => w.op == AlignmentOp.insertion).length;

  /// Proportion of script words said correctly, 0..1.
  ///
  /// Insertions are deliberately *not* in the denominator. A stumble that adds
  /// a word is a different failure from dropping one, and folding them together
  /// would let a user who restarted a sentence score worse than one who skipped
  /// it entirely.
  double get accuracy => expectedCount == 0 ? 0 : matches / expectedCount;

  /// Classic word error rate, which does count insertions. Reported alongside
  /// accuracy because it is the number an audio engineer would expect.
  double get wordErrorRate => expectedCount == 0
      ? 0
      : (substitutions + omissions + insertions) / expectedCount;

  /// Script words that did not survive, in script order. This is what the
  /// feedback screen highlights.
  List<AlignedWord> get missed => words
      .where(
        (w) => w.op == AlignmentOp.omission || w.op == AlignmentOp.substitution,
      )
      .toList();
}

/// Normalises text for comparison.
///
/// Recognisers are inconsistent about punctuation, capitalisation, numerals and
/// contractions, and none of those differences mean the user misspoke. Comparing
/// raw strings would punish people for the recogniser's formatting choices.
class TextNormaliser {
  const TextNormaliser._();

  static final _apostrophes = RegExp(r"[‘’ʼ]");
  static final _nonWord = RegExp(r"[^a-z0-9' ]");
  static final _whitespace = RegExp(r'\s+');

  /// Common recogniser spellings that should not count as errors.
  static const _equivalents = <String, String>{
    'ok': 'okay',
    'alright': 'all right',
    'gonna': 'going to',
    'wanna': 'want to',
    'cannot': 'can not',
    "can't": 'can not',
    "don't": 'do not',
    "won't": 'will not',
    "it's": 'it is',
    "i'm": 'i am',
    "i'll": 'i will',
    "you're": 'you are',
    "they're": 'they are',
    "that's": 'that is',
    "isn't": 'is not',
    "wasn't": 'was not',
    "doesn't": 'does not',
    "didn't": 'did not',
    "couldn't": 'could not',
    "wouldn't": 'would not',
    "shouldn't": 'should not',
  };

  static const _numerals = <String, String>{
    '0': 'zero',
    '1': 'one',
    '2': 'two',
    '3': 'three',
    '4': 'four',
    '5': 'five',
    '6': 'six',
    '7': 'seven',
    '8': 'eight',
    '9': 'nine',
    '10': 'ten',
  };

  /// Splits text into comparable words.
  static List<String> words(String text) {
    var normalised = text
        .toLowerCase()
        .replaceAll(_apostrophes, "'")
        .replaceAll(_nonWord, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();

    if (normalised.isEmpty) return const [];

    final out = <String>[];
    for (final token in normalised.split(' ')) {
      if (token.isEmpty) continue;
      final expanded = _equivalents[token] ?? _numerals[token] ?? token;
      // An expansion may introduce a space ("can not"), so split again.
      out.addAll(expanded.split(' ').where((w) => w.isNotEmpty));
    }
    return out;
  }
}

/// Aligns a transcript against a script.
///
/// Needleman–Wunsch over words. Chosen over a greedy pass because a single
/// dropped word early in a line would otherwise throw every subsequent
/// comparison out of step and report a near-total failure on a read that was
/// almost perfect.
class TranscriptAligner {
  const TranscriptAligner({this.substitutionCost = 1, this.gapCost = 1});

  final int substitutionCost;
  final int gapCost;

  TranscriptAlignment align({
    required String script,
    required String transcript,
    List<double>? wordConfidences,
  }) {
    final expected = TextNormaliser.words(script);
    final heard = TextNormaliser.words(transcript);

    if (expected.isEmpty) {
      return TranscriptAlignment(
        words: heard
            .map((w) => AlignedWord(op: AlignmentOp.insertion, heard: w))
            .toList(),
        expectedCount: 0,
      );
    }

    final rows = expected.length + 1;
    final columns = heard.length + 1;

    // cost[i][j] — cheapest alignment of the first i expected words with the
    // first j heard words.
    final cost = List.generate(rows, (_) => List<int>.filled(columns, 0));
    for (var i = 1; i < rows; i++) {
      cost[i][0] = i * gapCost;
    }
    for (var j = 1; j < columns; j++) {
      cost[0][j] = j * gapCost;
    }

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < columns; j++) {
        final same = expected[i - 1] == heard[j - 1];
        final diagonal = cost[i - 1][j - 1] + (same ? 0 : substitutionCost);
        final up = cost[i - 1][j] + gapCost;
        final left = cost[i][j - 1] + gapCost;
        cost[i][j] = diagonal < up
            ? (diagonal < left ? diagonal : left)
            : (up < left ? up : left);
      }
    }

    // Trace back. Ties prefer the diagonal so a match is never reported as an
    // omission plus an insertion, which would double-count one error.
    final words = <AlignedWord>[];
    var i = expected.length;
    var j = heard.length;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final same = expected[i - 1] == heard[j - 1];
        final diagonal = cost[i - 1][j - 1] + (same ? 0 : substitutionCost);
        if (cost[i][j] == diagonal) {
          words.add(
            AlignedWord(
              op: same ? AlignmentOp.match : AlignmentOp.substitution,
              expected: expected[i - 1],
              heard: heard[j - 1],
              expectedIndex: i - 1,
              confidence: _confidenceAt(wordConfidences, j - 1),
            ),
          );
          i--;
          j--;
          continue;
        }
      }
      if (i > 0 && cost[i][j] == cost[i - 1][j] + gapCost) {
        words.add(
          AlignedWord(
            op: AlignmentOp.omission,
            expected: expected[i - 1],
            expectedIndex: i - 1,
          ),
        );
        i--;
        continue;
      }
      words.add(
        AlignedWord(
          op: AlignmentOp.insertion,
          heard: heard[j - 1],
          confidence: _confidenceAt(wordConfidences, j - 1),
        ),
      );
      j--;
    }

    return TranscriptAlignment(
      words: words.reversed.toList(),
      expectedCount: expected.length,
    );
  }

  static double? _confidenceAt(List<double>? confidences, int index) {
    if (confidences == null) return null;
    if (index < 0 || index >= confidences.length) return null;
    return confidences[index];
  }
}
