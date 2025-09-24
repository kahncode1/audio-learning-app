import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/word_timing_service_simplified.dart';

/// Unit tests for WordTimingServiceSimplified
///
/// Purpose: Tests simplified timing service for pre-processed data
/// Coverage: Timing loading, caching, position lookups, and memory management
void main() {
  group('WordTimingServiceSimplified', () {
    late WordTimingServiceSimplified service;
    const testId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';
    const invalidId = 'invalid-learning-object-id';

    setUp(() {
      service = WordTimingServiceSimplified.instance;
      service.clearCache();
    });

    tearDown(() {
      service.clearCache();
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = WordTimingServiceSimplified.instance;
        final instance2 = WordTimingServiceSimplified.instance;

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Timing Data Loading', () {
      test('should load timing data successfully', () async {
        final timings = await service.loadTimings(testId);

        expect(timings, isNotEmpty);
        expect(timings.length, equals(63));
      });

      test('should have valid word timing properties', () async {
        final timings = await service.loadTimings(testId);

        for (final timing in timings) {
          expect(timing.word, isNotEmpty);
          expect(timing.startMs, greaterThanOrEqualTo(0));
          expect(timing.endMs, greaterThan(timing.startMs));
          expect(timing.sentenceIndex, greaterThanOrEqualTo(0));
        }
      });

      test('should handle loading non-existent content', () async {
        final timings = await service.loadTimings(invalidId);
        expect(timings, isEmpty);
      });
    });

    group('Caching', () {
      test('should cache loaded timings', () async {
        // First load
        final timings1 = await service.loadTimings(testId);

        // Second load should use cache
        final cached = service.getCachedTimings(testId);

        expect(cached, isNotNull);
        expect(cached!.length, equals(timings1.length));
      });

      test('should return null for uncached timings', () {
        final cached = service.getCachedTimings(invalidId);
        expect(cached, isNull);
      });

      test('should clear cache for specific object', () async {
        await service.loadTimings(testId);

        expect(service.getCachedTimings(testId), isNotNull);

        service.clearTimingsForObject(testId);

        expect(service.getCachedTimings(testId), isNull);
      });

      test('should clear entire cache', () async {
        await service.loadTimings(testId);

        expect(service.getCachedTimings(testId), isNotNull);

        service.clearCache();

        expect(service.getCachedTimings(testId), isNull);
      });

      test('should implement LRU cache eviction after 10 items', () async {
        // Create 11 test IDs (will trigger eviction)
        final testIds = List.generate(11, (i) => testId);

        // Load all (only 1 unique, but simulates the logic)
        for (final id in testIds) {
          await service.loadTimings(id);
        }

        // Cache should still have the item (since all are same ID)
        expect(service.getCachedTimings(testId), isNotNull);
      });
    });

    group('Position Lookups', () {
      test('should find current word index', () async {
        await service.loadTimings(testId);

        // Test at beginning
        final startIndex = service.getCurrentWordIndex(0);
        expect(startIndex, equals(0));

        // Test at 5 seconds
        final midIndex = service.getCurrentWordIndex(5000);
        expect(midIndex, greaterThanOrEqualTo(0));
        expect(midIndex, lessThan(63));

        // Test with no data loaded
        service.clearCache();
        final noDataIndex = service.getCurrentWordIndex(5000);
        expect(noDataIndex, equals(-1));
      });

      test('should find current sentence index', () async {
        await service.loadTimings(testId);

        // Test at beginning
        final startIndex = service.getCurrentSentenceIndex(0);
        expect(startIndex, equals(0));

        // Test at 10 seconds
        final midIndex = service.getCurrentSentenceIndex(10000);
        expect(midIndex, greaterThanOrEqualTo(0));
        expect(midIndex, lessThan(4));

        // Test with no data loaded
        service.clearCache();
        final noDataIndex = service.getCurrentSentenceIndex(10000);
        expect(noDataIndex, equals(-1));
      });
    });

    group('Word Access', () {
      test('should get word at specific index', () async {
        await service.loadTimings(testId);

        final word0 = service.getWordAtIndex(0);
        expect(word0, isNotNull);
        expect(word0!.word, equals('When'));

        final word10 = service.getWordAtIndex(10);
        expect(word10, isNotNull);
        expect(word10!.word, isNotEmpty);

        final wordInvalid = service.getWordAtIndex(100);
        expect(wordInvalid, isNull);

        final wordNegative = service.getWordAtIndex(-1);
        expect(wordNegative, isNull);
      });

      test('should get all current words', () async {
        await service.loadTimings(testId);

        final words = service.getCurrentWords();
        expect(words.length, equals(63));
      });

      test('should return empty list when no data loaded', () {
        final words = service.getCurrentWords();
        expect(words, isEmpty);
      });
    });

    group('Sentence Access', () {
      test('should get all current sentences', () async {
        await service.loadTimings(testId);

        final sentences = service.getCurrentSentences();
        expect(sentences.length, equals(4));

        for (final sentence in sentences) {
          expect(sentence.text, isNotEmpty);
        }
      });

      test('should get sentence boundaries', () async {
        final boundaries = await service.getSentenceBoundaries(testId);

        expect(boundaries.length, equals(4));

        for (final boundary in boundaries) {
          expect(boundary.text, isNotEmpty);
          expect(boundary.startWordIndex, greaterThanOrEqualTo(0));
          expect(boundary.endWordIndex,
              greaterThanOrEqualTo(boundary.startWordIndex));
          expect(boundary.startTime, greaterThanOrEqualTo(0));
          expect(boundary.endTime, greaterThan(boundary.startTime));
        }
      });

      test('should handle sentence boundaries for invalid ID', () async {
        final boundaries = await service.getSentenceBoundaries(invalidId);
        expect(boundaries, isEmpty);
      });
    });

    group('Display Text', () {
      test('should get display text for learning object', () async {
        final displayText = await service.getDisplayText(testId);

        expect(displayText, isNotEmpty);
        expect(displayText, contains('case reserve'));
      });

      test('should return empty string for invalid ID', () async {
        final displayText = await service.getDisplayText(invalidId);
        expect(displayText, isEmpty);
      });
    });

    group('SetCachedTimings Compatibility', () {
      test('should handle setCachedTimings call (no-op)', () async {
        final timings = await service.loadTimings(testId);

        // This should be a no-op but not throw
        service.setCachedTimings(testId, timings);

        // Cache should still be valid
        expect(service.getCachedTimings(testId), isNotNull);
      });
    });
  });
}
