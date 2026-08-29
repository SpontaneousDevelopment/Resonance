import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/domain/scoring/transcript_alignment.dart';

const aligner = TranscriptAligner();

void main() {
  group('normalisation', () {
    test('ignores case and punctuation', () {
      expect(TextNormaliser.words('Peter picked, a bitter batch!'), [
        'peter',
        'picked',
        'a',
        'bitter',
        'batch',
      ]);
    });

    test('treats curly and straight apostrophes alike', () {
      expect(TextNormaliser.words('don’t'), TextNormaliser.words("don't"));
    });

    test('expands contractions so the recogniser style does not matter', () {
      // Recognisers vary on whether they emit "don't" or "do not"; neither is
      // a mistake by the speaker.
      expect(TextNormaliser.words("don't"), ['do', 'not']);
      expect(TextNormaliser.words('do not'), ['do', 'not']);
    });

    test('spells out small numerals', () {
      expect(TextNormaliser.words('at 8'), ['at', 'eight']);
      expect(TextNormaliser.words('at eight'), ['at', 'eight']);
    });

    test('collapses runs of whitespace', () {
      expect(TextNormaliser.words('  a   b \n c '), ['a', 'b', 'c']);
    });

    test('empty and punctuation-only text yield no words', () {
      expect(TextNormaliser.words(''), isEmpty);
      expect(TextNormaliser.words('...  !!'), isEmpty);
    });
  });

  group('a perfect read', () {
    test('scores full accuracy', () {
      final result = aligner.align(
        script: 'Peter picked a bitter batch of pickled peppers.',
        transcript: 'peter picked a bitter batch of pickled peppers',
      );

      expect(result.accuracy, 1.0);
      expect(result.omissions, 0);
      expect(result.substitutions, 0);
      expect(result.insertions, 0);
      expect(result.missed, isEmpty);
    });

    test('punctuation and casing differences are not errors', () {
      final result = aligner.align(
        script: 'It is not complicated. He just has to answer the phone.',
        transcript: 'it is not complicated he just has to answer the phone',
      );

      expect(result.accuracy, 1.0);
    });
  });

  group('omissions', () {
    test('a dropped word is reported as an omission, not a cascade', () {
      // The property that matters: one dropped word early must not throw the
      // rest out of step. A greedy comparison would report near-total failure.
      final result = aligner.align(
        script: 'the rugged brigadier bragged briefly about the burglary',
        transcript: 'the rugged bragged briefly about the burglary',
      );

      expect(result.omissions, 1);
      expect(result.matches, 7);
      expect(result.missed.single.expected, 'brigadier');
    });

    test('several scattered omissions are each found', () {
      final result = aligner.align(
        script: 'she sells sea shells by the sea shore today',
        transcript: 'she sea shells by sea shore today',
      );

      expect(result.omissions, 2);
      expect(
        result.missed.map((w) => w.expected),
        containsAll(['sells', 'the']),
      );
    });
  });

  group('substitutions', () {
    test('a misheard word is a substitution, not omission plus insertion', () {
      // Double-counting one error would make a small articulation slip read as
      // two failures.
      final result = aligner.align(
        script: 'packed them tight',
        transcript: 'packed them tight',
      );
      expect(result.accuracy, 1.0);

      final slipped = aligner.align(
        script: 'peter picked a bitter batch',
        transcript: 'peter picked a bitter bat',
      );

      expect(slipped.substitutions, 1);
      expect(slipped.omissions, 0);
      expect(slipped.insertions, 0);
      expect(slipped.missed.single.expected, 'batch');
      expect(slipped.missed.single.heard, 'bat');
    });
  });

  group('insertions', () {
    test('a stumble adds an insertion without lowering accuracy', () {
      final result = aligner.align(
        script: 'let the vowel carry the line',
        transcript: 'let the the vowel carry the line',
      );

      expect(result.insertions, 1);
      // Every script word still arrived, so accuracy is intact...
      expect(result.accuracy, 1.0);
      // ...but the word error rate reflects the stumble.
      expect(result.wordErrorRate, greaterThan(0));
    });

    test('accuracy does not exceed one when the user says extra words', () {
      final result = aligner.align(
        script: 'answer the phone',
        transcript: 'just answer the phone right now please',
      );

      expect(result.accuracy, lessThanOrEqualTo(1.0));
      expect(result.insertions, 4);
    });
  });

  group('degenerate input', () {
    test('an empty transcript omits everything', () {
      final result = aligner.align(
        script: 'six slick sisters swiftly stitched',
        transcript: '',
      );

      expect(result.accuracy, 0);
      expect(result.omissions, 5);
    });

    test('an empty script treats everything as insertion', () {
      final result = aligner.align(script: '', transcript: 'hello there');

      expect(result.expectedCount, 0);
      expect(result.insertions, 2);
      expect(result.accuracy, 0);
    });

    test('both empty is handled', () {
      final result = aligner.align(script: '', transcript: '');
      expect(result.words, isEmpty);
    });

    test('a completely unrelated transcript scores near zero', () {
      final result = aligner.align(
        script: 'she sells sea shells',
        transcript: 'the quick brown fox',
      );

      expect(result.accuracy, 0);
    });
  });

  group('word order', () {
    test('missed words are returned in script order', () {
      final result = aligner.align(
        script: 'one two three four five six seven',
        transcript: 'one three four six seven',
      );

      expect(result.missed.map((w) => w.expected), ['two', 'five']);
    });

    test('expectedIndex points back into the script', () {
      final result = aligner.align(
        script: 'alpha bravo charlie delta',
        transcript: 'alpha charlie delta',
      );

      expect(result.missed.single.expected, 'bravo');
      expect(result.missed.single.expectedIndex, 1);
    });
  });

  group('confidence', () {
    test('per-word confidence is carried onto heard words', () {
      final result = aligner.align(
        script: 'alpha bravo charlie',
        transcript: 'alpha bravo charlie',
        wordConfidences: [0.9, 0.4, 0.8],
      );

      final matched = result.words
          .where((w) => w.op == AlignmentOp.match)
          .toList();
      expect(matched.map((w) => w.confidence), [0.9, 0.4, 0.8]);
    });

    test('a short confidence list does not throw', () {
      final result = aligner.align(
        script: 'alpha bravo charlie',
        transcript: 'alpha bravo charlie',
        wordConfidences: [0.9],
      );

      expect(result.accuracy, 1.0);
    });
  });

  group('realistic reads', () {
    test('a good read of the plosive lesson', () {
      const script =
          'Peter picked a bitter batch of pickled peppers, packed '
          'them tight, and put the barrel back beside the broken gate.';

      final result = aligner.align(
        script: script,
        transcript:
            'peter picked a bitter batch of pickled peppers packed '
            'them tight and put the barrel back beside the broken gate',
      );

      expect(result.accuracy, 1.0);
    });

    test('a read that drops final consonants', () {
      const script = 'packed them tight and put the barrel back';

      final result = aligner.align(
        script: script,
        transcript: 'pack them tie and put the barrel back',
      );

      expect(result.substitutions, 2);
      expect(
        result.missed.map((w) => w.expected),
        containsAll(['packed', 'tight']),
      );
    });
  });
}
