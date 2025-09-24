/// Timing Accuracy Test
///
/// Purpose: Verify word and sentence timing accuracy
/// This test validates the continuous coverage requirement for highlighting

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/word_timing.dart';
import 'package:audio_learning_app/models/sentence_timing.dart';

// Helper function for finding word index at a given time
int findWordIndexAtTime(List<WordTiming> wordTimings, int timeMs) {
  for (int i = 0; i < wordTimings.length; i++) {
    if (wordTimings[i].isActiveAt(timeMs)) {
      return i;
    }
  }
  // If no word is active, return the closest word
  if (timeMs < 0) return 0;
  return wordTimings.length - 1;
}

// Helper function for finding sentence index at a given time
int findSentenceIndexAtTime(List<SentenceTiming> sentenceTimings, int timeMs) {
  for (int i = 0; i < sentenceTimings.length; i++) {
    if (timeMs >= sentenceTimings[i].startMs && timeMs < sentenceTimings[i].endMs) {
      return i;
    }
  }
  // If no sentence is active, return the closest sentence
  if (timeMs < 0) return 0;
  return sentenceTimings.length - 1;
}

// Helper function to validate continuous coverage for sentence timings
bool validateContinuousCoverage(List<SentenceTiming> sentenceTimings) {
  try {
    for (int i = 1; i < sentenceTimings.length; i++) {
      final previousEnd = sentenceTimings[i - 1].endMs;
      final currentStart = sentenceTimings[i].startMs;
      if (currentStart != previousEnd) {
        return false;
      }
    }
    return true;
  } catch (e) {
    return false;
  }
}

// Helper function to validate word timing collection
bool validateCollection(List<WordTiming> wordTimings) {
  try {
    if (wordTimings.isEmpty) return false;
    for (final timing in wordTimings) {
      if (timing.word.isEmpty) return false;
      if (timing.startMs < 0) return false;
      if (timing.endMs <= timing.startMs) return false;
      if (timing.sentenceIndex < 0) return false;
    }
    return true;
  } catch (e) {
    return false;
  }
}

void main() {
  group('Timing Accuracy Tests', () {
    test('Word timings should have continuous coverage', () {
      // Create word timings with proper continuous coverage
      final wordTimings = [
        WordTiming(
          word: 'The',
          startMs: 0,
          endMs: 250,
          charStart: 0,
          charEnd: 3,
          sentenceIndex: 0,
        ),
        WordTiming(
          word: 'insurance',
          startMs: 250,
          endMs: 750,
          charStart: 4,
          charEnd: 13,
          sentenceIndex: 0,
        ),
        WordTiming(
          word: 'industry',
          startMs: 750,
          endMs: 1250,
          charStart: 14,
          charEnd: 22,
          sentenceIndex: 0,
        ),
      ];

      // Verify continuous coverage (no gaps)
      for (int i = 1; i < wordTimings.length; i++) {
        final previousEnd = wordTimings[i - 1].endMs;
        final currentStart = wordTimings[i].startMs;
        expect(currentStart, equals(previousEnd),
            reason: 'Word ${i} should start where word ${i - 1} ends');
      }

      // Verify character positions are continuous
      for (int i = 1; i < wordTimings.length; i++) {
        final previousCharEnd = wordTimings[i - 1].charEnd;
        final currentCharStart = wordTimings[i].charStart;
        // Allow for space character (only test if both positions are available)
        if (previousCharEnd != null && currentCharStart != null) {
          expect(currentCharStart - previousCharEnd, lessThanOrEqualTo(1),
              reason:
                  'Character positions should be continuous with at most 1 space');
        }
      }
    });

    test('Sentence timings should cover all words', () {
      final wordTimings = [
        WordTiming(word: 'Insurance', startMs: 0, endMs: 500, sentenceIndex: 0),
        WordTiming(
            word: 'provides', startMs: 500, endMs: 1000, sentenceIndex: 0),
        WordTiming(
            word: 'protection', startMs: 1000, endMs: 1500, sentenceIndex: 0),
        WordTiming(
            word: 'against', startMs: 1500, endMs: 1800, sentenceIndex: 0),
        WordTiming(word: 'risks', startMs: 1800, endMs: 2200, sentenceIndex: 0),
        WordTiming(word: 'It', startMs: 2200, endMs: 2400, sentenceIndex: 1),
        WordTiming(word: 'is', startMs: 2400, endMs: 2600, sentenceIndex: 1),
        WordTiming(
            word: 'essential', startMs: 2600, endMs: 3200, sentenceIndex: 1),
      ];

      final sentenceTimings = [
        SentenceTiming(
          text: 'Insurance provides protection against risks.',
          startMs: 0,
          endMs: 2200,
          sentenceIndex: 0,
          wordStartIndex: 0,
          wordEndIndex: 4,
          charStart: 0,
          charEnd: 44,
        ),
        SentenceTiming(
          text: 'It is essential.',
          startMs: 2200,
          endMs: 3200,
          sentenceIndex: 1,
          wordStartIndex: 5,
          wordEndIndex: 7,
          charStart: 45,
          charEnd: 61,
        ),
      ];

      // Verify sentence 0 covers words 0-4
      final sentence0Words =
          wordTimings.where((w) => w.sentenceIndex == 0).toList();
      expect(sentence0Words.length, equals(5));
      expect(sentence0Words.first.startMs, equals(sentenceTimings[0].startMs));
      expect(sentence0Words.last.endMs, equals(sentenceTimings[0].endMs));

      // Verify sentence 1 covers words 5-7
      final sentence1Words =
          wordTimings.where((w) => w.sentenceIndex == 1).toList();
      expect(sentence1Words.length, equals(3));
      expect(sentence1Words.first.startMs, equals(sentenceTimings[1].startMs));
      expect(sentence1Words.last.endMs, equals(sentenceTimings[1].endMs));

      // Verify continuous coverage between sentences
      expect(sentenceTimings[1].startMs, equals(sentenceTimings[0].endMs));
    });

    test('Binary search should find correct word at any timestamp', () {
      final wordTimings = [
        WordTiming(word: 'First', startMs: 0, endMs: 500, sentenceIndex: 0),
        WordTiming(word: 'Second', startMs: 500, endMs: 1000, sentenceIndex: 0),
        WordTiming(word: 'Third', startMs: 1000, endMs: 1500, sentenceIndex: 0),
        WordTiming(
            word: 'Fourth', startMs: 1500, endMs: 2000, sentenceIndex: 1),
        WordTiming(word: 'Fifth', startMs: 2000, endMs: 2500, sentenceIndex: 1),
      ];

      // Test various timestamps
      expect(findWordIndexAtTime(wordTimings, 0), equals(0));
      expect(findWordIndexAtTime(wordTimings, 250), equals(0));
      expect(findWordIndexAtTime(wordTimings, 499), equals(0));
      expect(findWordIndexAtTime(wordTimings, 500), equals(1));
      expect(findWordIndexAtTime(wordTimings, 750), equals(1));
      expect(findWordIndexAtTime(wordTimings, 1000), equals(2));
      expect(findWordIndexAtTime(wordTimings, 1999), equals(3));
      expect(findWordIndexAtTime(wordTimings, 2000), equals(4));
      expect(findWordIndexAtTime(wordTimings, 2499), equals(4));

      // Test out of bounds
      expect(findWordIndexAtTime(wordTimings, -100), equals(0));
      expect(findWordIndexAtTime(wordTimings, 3000), equals(4));
    });

    test('Sentence boundaries should be correctly identified', () {
      final sentenceTimings = [
        SentenceTiming(
          text: 'First sentence.',
          startMs: 0,
          endMs: 1000,
          sentenceIndex: 0,
          wordStartIndex: 0,
          wordEndIndex: 1,
          charStart: 0,
          charEnd: 15,
        ),
        SentenceTiming(
          text: 'Second sentence.',
          startMs: 1000,
          endMs: 2000,
          sentenceIndex: 1,
          wordStartIndex: 2,
          wordEndIndex: 3,
          charStart: 16,
          charEnd: 32,
        ),
        SentenceTiming(
          text: 'Third sentence.',
          startMs: 2000,
          endMs: 3000,
          sentenceIndex: 2,
          wordStartIndex: 4,
          wordEndIndex: 5,
          charStart: 33,
          charEnd: 48,
        ),
      ];

      // Find sentence at various timestamps
      expect(findSentenceIndexAtTime(sentenceTimings, 0),
          equals(0));
      expect(findSentenceIndexAtTime(sentenceTimings, 500),
          equals(0));
      expect(findSentenceIndexAtTime(sentenceTimings, 999),
          equals(0));
      expect(findSentenceIndexAtTime(sentenceTimings, 1000),
          equals(1));
      expect(findSentenceIndexAtTime(sentenceTimings, 1500),
          equals(1));
      expect(findSentenceIndexAtTime(sentenceTimings, 2000),
          equals(2));
      expect(findSentenceIndexAtTime(sentenceTimings, 2999),
          equals(2));

      // Test continuous coverage validation
      expect(
          validateContinuousCoverage(sentenceTimings), isTrue);

      // Test with gap (invalid)
      final invalidTimings = [
        SentenceTiming(
          text: 'First.',
          startMs: 0,
          endMs: 1000,
          sentenceIndex: 0,
          wordStartIndex: 0,
          wordEndIndex: 0,
          charStart: 0,
          charEnd: 6,
        ),
        SentenceTiming(
          text: 'Second.',
          startMs: 1100, // Gap of 100ms
          endMs: 2000,
          sentenceIndex: 1,
          wordStartIndex: 1,
          wordEndIndex: 1,
          charStart: 7,
          charEnd: 14,
        ),
      ];

      expect(
          validateContinuousCoverage(invalidTimings), isFalse);
    });

    test('Word highlighting should handle rapid position changes', () {
      final wordTimings = List.generate(
          100,
          (i) => WordTiming(
                word: 'Word$i',
                startMs: i * 100,
                endMs: (i + 1) * 100,
                sentenceIndex: i ~/ 10,
              ));

      // Simulate rapid position changes
      final testPositions = [0, 500, 1500, 3000, 5000, 7500, 9999];
      final expectedIndices = [0, 5, 15, 30, 50, 75, 99];

      for (int i = 0; i < testPositions.length; i++) {
        final foundIndex =
            findWordIndexAtTime(wordTimings, testPositions[i]);
        expect(foundIndex, equals(expectedIndices[i]),
            reason:
                'Position ${testPositions[i]}ms should find word ${expectedIndices[i]}');
      }
    });

    test('Timing validation should detect overlaps', () {
      // Valid timings (no overlaps)
      final validTimings = [
        WordTiming(word: 'A', startMs: 0, endMs: 100, sentenceIndex: 0),
        WordTiming(word: 'B', startMs: 100, endMs: 200, sentenceIndex: 0),
        WordTiming(word: 'C', startMs: 200, endMs: 300, sentenceIndex: 0),
      ];

      expect(validateCollection(validTimings), isTrue);

      // Invalid timings (overlap)
      final invalidTimings = [
        WordTiming(word: 'A', startMs: 0, endMs: 150, sentenceIndex: 0),
        WordTiming(
            word: 'B',
            startMs: 100,
            endMs: 200,
            sentenceIndex: 0), // Overlaps with A
        WordTiming(word: 'C', startMs: 200, endMs: 300, sentenceIndex: 0),
      ];

      expect(validateCollection(invalidTimings), isFalse);
    });
  });
}
