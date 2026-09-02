/// Splits a lesson brief into the beats it is read in.
///
/// The pre-exercise cards show one beat at a time, so where one idea ends and
/// the next begins decides the pacing of the whole screen. That is an authorial
/// call, and this makes none of it: it splits on punctuation the author already
/// wrote — paragraph breaks first, then sentence endings — and never on a
/// length. A character-count split would put a break wherever the text happened
/// to reach eighty characters, which is a decision about typography pretending
/// to be a decision about meaning.
///
/// The consequence is deliberate: a brief that paces badly is fixed in the
/// brief. `t1u1l4` had a 35-word sentence that made one card a wall of text, and
/// the fix was a full stop where the author had written a colon, not a smarter
/// splitter.
library;

/// Sentence end, followed by whitespace and something that starts a new one.
///
/// Requiring a capital or an opening quote next keeps decimals and abbreviations
/// together. No brief contains either today, but the rule costs nothing.
final _sentenceEnd = RegExp('(?<=[.!?])\\s+(?=[A-Z“"‘\'])');

/// A blank line — an explicit paragraph break, which outranks sentence endings.
final _paragraphBreak = RegExp(r'\n\s*\n');

List<String> briefChunks(String brief) {
  final trimmed = brief.trim();
  if (trimmed.isEmpty) return const [];

  final paragraphs = trimmed
      .split(_paragraphBreak)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  // A brief written in paragraphs is already chunked by its author; splitting
  // those further would override a decision they made.
  if (paragraphs.length > 1) return paragraphs;

  final sentences = trimmed
      .split(_sentenceEnd)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  return sentences.isEmpty ? [trimmed] : sentences;
}
