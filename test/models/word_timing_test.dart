/// Unit Tests for Optimized WordTiming and WordTimingCollection
///
/// Purpose: Test binary search optimizations, caching mechanisms, and performance
/// Features tested:
/// - Binary search with locality caching
/// - Sentence caching and boundaries
/// - Performance characteristics
/// - Edge cases and error handling
/// - Range queries and text search

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/word_timing.dart';

void main() {
  group('WordTiming Model', () {
    test('should serialize and deserialize correctly', () {
      final timing = WordTiming(
        word: 'hello',
        startMs: 1000,
        endMs: 1500,
        sentenceIndex: 2,
      );

      final json = timing.toJson();
      final reconstructed = WordTiming.fromJson(json);

      expect(reconstructed.word, equals(timing.word));
      expect(reconstructed.startMs, equals(timing.startMs));
      expect(reconstructed.endMs, equals(timing.endMs));
      expect(reconstructed.sentenceIndex, equals(timing.sentenceIndex));
    });

    test('should calculate duration correctly', () {
      final timing = WordTiming(
        word: 'test',
        startMs: 1000,
        endMs: 2500,
        sentenceIndex: 0,
      );

      expect(timing.durationMs, equals(1500));
    });

    test('should detect active time correctly', () {
      final timing = WordTiming(
        word: 'active',
        startMs: 1000,
        endMs: 2000,
        sentenceIndex: 0,
      );

      expect(timing.isActiveAt(500), isFalse); // Before start
      expect(timing.isActiveAt(1000), isTrue); // At start
      expect(timing.isActiveAt(1500), isTrue); // In middle
      expect(timing.isActiveAt(1999), isTrue); // Just before end
      expect(timing.isActiveAt(2000), isFalse); // At end (exclusive)
      expect(timing.isActiveAt(2500), isFalse); // After end
    });

    test('should handle sentence detection correctly', () {
      final timings = [
        WordTiming(word: 'Hello', startMs: 0, endMs: 500, sentenceIndex: 0),
        WordTiming(word: 'world', startMs: 500, endMs: 1000, sentenceIndex: 0),
        WordTiming(word: 'How', startMs: 1500, endMs: 2000, sentenceIndex: 1),
      ];

      final firstTiming = timings[0];
      expect(firstTiming.isSentenceActiveAt(250, timings), isTrue);
      expect(firstTiming.isSentenceActiveAt(750, timings), isTrue);
      expect(firstTiming.isSentenceActiveAt(1250, timings), isFalse);
    });

    test('should validate with assertions', () {
      expect(
        () => WordTiming(word: '', startMs: 0, endMs: 100, sentenceIndex: 0),
        throwsAssertionError,
      );

      expect(
        () => WordTiming(word: 'test', startMs: -1, endMs: 100, sentenceIndex: 0),
        throwsAssertionError,
      );

      expect(
        () => WordTiming(word: 'test', startMs: 100, endMs: 50, sentenceIndex: 0),
        throwsAssertionError,
      );
    });
  });

  group('WordTimingCollection - Basic Operations', () {
    late List<WordTiming> testTimings;
    late WordTimingCollection collection;

    setUp(() {
      testTimings = [
        WordTiming(word: 'This', startMs: 0, endMs: 400, sentenceIndex: 0),
        WordTiming(word: 'is', startMs: 400, endMs: 600, sentenceIndex: 0),
        WordTiming(word: 'sentence', startMs: 600, endMs: 1000, sentenceIndex: 0),
        WordTiming(word: 'one.', startMs: 1000, endMs: 1400, sentenceIndex: 0),
        WordTiming(word: 'Here', startMs: 1800, endMs: 2200, sentenceIndex: 1),
        WordTiming(word: 'is', startMs: 2200, endMs: 2400, sentenceIndex: 1),
        WordTiming(word: 'sentence', startMs: 2400, endMs: 2800, sentenceIndex: 1),
        WordTiming(word: 'two.', startMs: 2800, endMs: 3200, sentenceIndex: 1),
      ];
      collection = WordTimingCollection(testTimings);
    });

    test('should validate integrity correctly', () {
      expect(collection.validateIntegrity(), isTrue);

      // Test with invalid data
      final invalidTimings = [
        WordTiming(word: 'Second', startMs: 1000, endMs: 1500, sentenceIndex: 0),
        WordTiming(word: 'First', startMs: 0, endMs: 500, sentenceIndex: 0), // Out of order
      ];
      final invalidCollection = WordTimingCollection(invalidTimings);
      expect(invalidCollection.validateIntegrity(), isFalse);
    });

    test('should get collection statistics correctly', () {
      expect(collection.sentenceCount, equals(2));
      expect(collection.totalDurationMs, equals(3200));
    });

    test('should build sentence cache on initialization', () {
      final sentence0Words = collection.getWordsInSentence(0);
      expect(sentence0Words.length, equals(4));
      expect(sentence0Words.first.word, equals('This'));
      expect(sentence0Words.last.word, equals('one.'));

      final sentence1Words = collection.getWordsInSentence(1);
      expect(sentence1Words.length, equals(4));
      expect(sentence1Words.first.word, equals('Here'));
      expect(sentence1Words.last.word, equals('two.'));
    });

    test('should return cached sentence boundaries', () {
      final boundaries0 = collection.getSentenceBoundaries(0);
      expect(boundaries0, isNotNull);
      expect(boundaries0!.$1, equals(0));
      expect(boundaries0.$2, equals(1400));

      final boundaries1 = collection.getSentenceBoundaries(1);
      expect(boundaries1, isNotNull);
      expect(boundaries1!.$1, equals(1800));
      expect(boundaries1.$2, equals(3200));

      final nonExistent = collection.getSentenceBoundaries(5);
      expect(nonExistent, isNull);
    });
  });

  group('WordTimingCollection - Binary Search Optimization', () {
    late List<WordTiming> testTimings;
    late WordTimingCollection collection;

    setUp(() {
      // Create more extensive test data for performance testing
      testTimings = [];
      for (int i = 0; i < 100; i++) {
        testTimings.add(WordTiming(
          word: 'word$i',
          startMs: i * 100,
          endMs: (i * 100) + 80,
          sentenceIndex: i ~/ 10, // 10 words per sentence
        ));
      }
      collection = WordTimingCollection(testTimings);
    });

    test('should find active word index correctly', () {
      // Test exact matches
      expect(collection.findActiveWordIndex(50), equals(0)); // Middle of first word
      expect(collection.findActiveWordIndex(150), equals(1)); // Middle of second word
      expect(collection.findActiveWordIndex(9950), equals(99)); // Last word

      // Test edge cases
      expect(collection.findActiveWordIndex(-100), equals(-1)); // Before any word
      expect(collection.findActiveWordIndex(10000), equals(-1)); // After all words

      // Test gaps between words
      expect(collection.findActiveWordIndex(90), equals(-1)); // Gap between word 0 and 1
    });

    test('should find active sentence index correctly', () {
      expect(collection.findActiveSentenceIndex(50), equals(0)); // First sentence
      expect(collection.findActiveSentenceIndex(1050), equals(1)); // Second sentence
      expect(collection.findActiveSentenceIndex(9950), equals(9)); // Last sentence
      expect(collection.findActiveSentenceIndex(-100), equals(-1)); // Invalid time
    });

    test('should demonstrate locality caching performance', () {
      collection.resetLocalityCache();

      // Simulate sequential playback - should be faster due to locality
      final sequentialStopwatch = Stopwatch()..start();
      for (int time = 0; time < 10000; time += 50) {
        collection.findActiveWordIndex(time);
      }
      sequentialStopwatch.stop();

      // Reset and test random access - should be slower
      collection.resetLocalityCache();
      final randomStopwatch = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        final randomTime = (i * 37) % 10000; // Pseudo-random pattern
        collection.findActiveWordIndex(randomTime);
      }
      randomStopwatch.stop();

      // Sequential should be significantly faster than random
      expect(sequentialStopwatch.elapsedMicroseconds,
          lessThan(randomStopwatch.elapsedMicroseconds));
    });

    test('should perform well with large datasets', () {
      final stopwatch = Stopwatch()..start();

      // Perform many searches
      for (int i = 0; i < 1000; i++) {
        collection.findActiveWordIndex(i * 10);
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Should be very fast
    });

    test('should handle adjacent word searches efficiently', () {
      // Start at middle of dataset
      final startIndex = collection.findActiveWordIndex(5050);
      expect(startIndex, equals(50));

      // Search adjacent positions - should use locality cache
      final nextIndex = collection.findActiveWordIndex(5150);
      expect(nextIndex, equals(51));

      final prevIndex = collection.findActiveWordIndex(4950);
      expect(prevIndex, equals(49));
    });
  });

  group('WordTimingCollection - Advanced Features', () {
    late List<WordTiming> testTimings;
    late WordTimingCollection collection;

    setUp(() {
      testTimings = [
        WordTiming(word: 'Apple', startMs: 0, endMs: 500, sentenceIndex: 0),
        WordTiming(word: 'banana', startMs: 500, endMs: 1000, sentenceIndex: 0),
        WordTiming(word: 'Cherry', startMs: 1000, endMs: 1500, sentenceIndex: 0),
        WordTiming(word: 'date', startMs: 2000, endMs: 2500, sentenceIndex: 1),
        WordTiming(word: 'elderberry', startMs: 2500, endMs: 3000, sentenceIndex: 1),
      ];
      collection = WordTimingCollection(testTimings);
    });

    test('should find words by text correctly', () {
      expect(collection.findWordIndexByText('Apple'), equals(0));
      expect(collection.findWordIndexByText('apple'), equals(0)); // Case insensitive
      expect(collection.findWordIndexByText('BANANA'), equals(1));
      expect(collection.findWordIndexByText('elderberry'), equals(4));
      expect(collection.findWordIndexByText('grape'), equals(-1)); // Not found

      // Test starting from specific index
      expect(collection.findWordIndexByText('date', startIndex: 2), equals(3));
      expect(collection.findWordIndexByText('Apple', startIndex: 2), equals(-1));
    });

    test('should find words in time range correctly', () {
      // Range covering first two words
      final range1 = collection.getWordIndicesInRange(200, 800);
      expect(range1, containsAll([0, 1]));
      expect(range1.length, equals(2));

      // Range covering gap and one word
      final range2 = collection.getWordIndicesInRange(1800, 2200);
      expect(range2, contains(3));
      expect(range2.length, equals(1));

      // Range covering multiple sentences
      final range3 = collection.getWordIndicesInRange(800, 2700);
      expect(range3, containsAll([2, 3, 4]));

      // Range with no words
      final range4 = collection.getWordIndicesInRange(1600, 1900);
      expect(range4, isEmpty);

      // Range extending beyond data
      final range5 = collection.getWordIndicesInRange(2800, 5000);
      expect(range5, contains(4));
      expect(range5.length, equals(1));
    });

    test('should handle empty collection gracefully', () {
      final emptyCollection = WordTimingCollection([]);

      expect(emptyCollection.findActiveWordIndex(1000), equals(-1));
      expect(emptyCollection.findActiveSentenceIndex(1000), equals(-1));
      expect(emptyCollection.getWordsInSentence(0), isEmpty);
      expect(emptyCollection.getSentenceBoundaries(0), isNull);
      expect(emptyCollection.findWordIndexByText('test'), equals(-1));
      expect(emptyCollection.getWordIndicesInRange(0, 1000), isEmpty);
      expect(emptyCollection.sentenceCount, equals(0));
      expect(emptyCollection.totalDurationMs, equals(0));
      expect(emptyCollection.validateIntegrity(), isTrue);
    });

    test('should return defensive copies of sentence words', () {
      final words1 = collection.getWordsInSentence(0);
      final words2 = collection.getWordsInSentence(0);

      expect(words1, isNot(same(words2))); // Different objects
      expect(words1, equals(words2)); // Same content

      // Modify one copy - should not affect the other
      words1.clear();
      expect(words2.length, greaterThan(0));
    });
  });

  group('WordTimingCollection - Edge Cases', () {
    test('should handle single word collection', () {
      final singleWord = [
        WordTiming(word: 'solo', startMs: 1000, endMs: 1500, sentenceIndex: 0)
      ];
      final collection = WordTimingCollection(singleWord);

      expect(collection.findActiveWordIndex(1250), equals(0));
      expect(collection.findActiveSentenceIndex(1250), equals(0));
      expect(collection.sentenceCount, equals(1));
      expect(collection.totalDurationMs, equals(500));
    });

    test('should handle words with zero duration', () {
      final zeroDuration = [
        WordTiming(word: 'instant', startMs: 1000, endMs: 1000, sentenceIndex: 0)
      ];
      final collection = WordTimingCollection(zeroDuration);

      expect(collection.findActiveWordIndex(1000), equals(-1)); // Zero duration = never active
      expect(collection.totalDurationMs, equals(0));
    });

    test('should handle words with same start time', () {
      final sameStart = [
        WordTiming(word: 'first', startMs: 1000, endMs: 1200, sentenceIndex: 0),
        WordTiming(word: 'second', startMs: 1000, endMs: 1300, sentenceIndex: 0),
      ];
      final collection = WordTimingCollection(sameStart);

      // Should find the first word with matching time
      final activeIndex = collection.findActiveWordIndex(1100);
      expect(activeIndex, isIn([0, 1])); // Either could be valid
    });

    test('should handle large sentence indices', () {
      final largeSentence = [
        WordTiming(word: 'test', startMs: 0, endMs: 500, sentenceIndex: 999)
      ];
      final collection = WordTimingCollection(largeSentence);

      expect(collection.findActiveSentenceIndex(250), equals(999));
      expect(collection.sentenceCount, equals(1000)); // 0-999 = 1000 sentences
    });

    test('should handle very large timestamps', () {
      final largeTime = [
        WordTiming(word: 'future', startMs: 999999000, endMs: 999999500, sentenceIndex: 0)
      ];
      final collection = WordTimingCollection(largeTime);

      expect(collection.findActiveWordIndex(999999250), equals(0));
      expect(collection.totalDurationMs, equals(500));
    });
  });

  group('WordTiming Validation', () {
    test('should pass comprehensive validation', () {
      expect(() => validateWordTimingModel(), returnsNormally);
    });
  });

  group('Performance Benchmarks', () {
    late WordTimingCollection largeCollection;

    setUpAll(() {
      // Create very large dataset for performance testing
      final largeTimings = <WordTiming>[];
      for (int i = 0; i < 10000; i++) {
        largeTimings.add(WordTiming(
          word: 'word$i',
          startMs: i * 100,
          endMs: (i * 100) + 90,
          sentenceIndex: i ~/ 100, // 100 words per sentence
        ));
      }
      largeCollection = WordTimingCollection(largeTimings);
    });

    test('should meet binary search performance requirements', () {
      final stopwatch = Stopwatch()..start();

      // Perform 1000 random searches
      for (int i = 0; i < 1000; i++) {
        final randomTime = (i * 317) % 1000000; // Pseudo-random
        largeCollection.findActiveWordIndex(randomTime);
      }

      stopwatch.stop();

      // Should complete 1000 searches in under 5ms (requirement from PLANNING.md)
      expect(stopwatch.elapsedMicroseconds, lessThan(5000));
      print('Performance: ${stopwatch.elapsedMicroseconds}μs for 1000 binary searches');
    });

    test('should meet locality caching performance requirements', () {
      largeCollection.resetLocalityCache();
      final stopwatch = Stopwatch()..start();

      // Simulate real-time playback with 60fps updates
      for (int frame = 0; frame < 3600; frame++) {
        final timeMs = frame * 16; // 16ms per frame = 60fps
        largeCollection.findActiveWordIndex(timeMs);
      }

      stopwatch.stop();

      // Should maintain 60fps performance (requirement: <16ms per update)
      final avgTimePerUpdate = stopwatch.elapsedMicroseconds / 3600;
      expect(avgTimePerUpdate, lessThan(16000)); // 16ms in microseconds
      print('Performance: ${avgTimePerUpdate.toStringAsFixed(1)}μs average per 60fps update');
    });

    test('should meet sentence operations performance requirements', () {
      final stopwatch = Stopwatch()..start();

      // Test sentence operations performance
      for (int i = 0; i < 1000; i++) {
        largeCollection.getSentenceBoundaries(i % 100);
        largeCollection.getWordsInSentence(i % 100);
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(10)); // Should be very fast due to caching
      print('Performance: ${stopwatch.elapsedMicroseconds}μs for 1000 sentence operations');
    });
  });
}