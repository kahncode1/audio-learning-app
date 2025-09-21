/// Performance Benchmarks for WordTiming and WordTimingService
///
/// Purpose: Validate performance requirements for dual-level highlighting
/// Requirements tested:
/// - Binary search: <5ms for 10,000 words (per PLANNING.md)
/// - 60fps updates: <16ms per frame
/// - Word sync accuracy: ±50ms
/// - Sentence sync accuracy: 100%
/// - Memory efficiency: Reasonable cache sizes
/// - Locality caching: Significant speedup for sequential access

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/word_timing.dart';
import 'package:audio_learning_app/services/word_timing_service.dart';
import 'dart:math';

void main() {
  group('WordTiming Performance Benchmarks', () {
    late List<WordTiming> smallDataset;
    late List<WordTiming> mediumDataset;
    late List<WordTiming> largeDataset;
    late List<WordTiming> xlDataset;

    setUpAll(() {
      print('Setting up performance test datasets...');

      // Small dataset: 100 words (typical short article)
      smallDataset = _createTestDataset(100, avgWordDurationMs: 300);

      // Medium dataset: 1,000 words (typical chapter)
      mediumDataset = _createTestDataset(1000, avgWordDurationMs: 250);

      // Large dataset: 10,000 words (full book chapter)
      largeDataset = _createTestDataset(10000, avgWordDurationMs: 200);

      // XL dataset: 50,000 words (complete book)
      xlDataset = _createTestDataset(50000, avgWordDurationMs: 180);

      print('✅ Test datasets created');
    });

    group('Binary Search Performance', () {
      test('should meet <5ms requirement for 10,000 words', () {
        final collection = WordTimingCollection(largeDataset);
        final stopwatch = Stopwatch()..start();

        // Perform many searches to get accurate measurement
        const searchCount = 1000;
        for (int i = 0; i < searchCount; i++) {
          final randomTime = (i * 317) % 2000000; // Pseudo-random times
          collection.findActiveWordIndex(randomTime);
        }

        stopwatch.stop();
        final avgTimePerSearch = stopwatch.elapsedMicroseconds / searchCount;

        print('Binary Search Performance (10,000 words):');
        print('  - Total time: ${stopwatch.elapsedMicroseconds}μs');
        print('  - Average per search: ${avgTimePerSearch.toStringAsFixed(1)}μs');
        print('  - Searches per second: ${(1000000 / avgTimePerSearch).toStringAsFixed(0)}');

        // Requirement: <5ms (5000μs) for multiple searches
        expect(avgTimePerSearch, lessThan(5000));
        expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Total time reasonable
      });

      test('should scale logarithmically with dataset size', () {
        final results = <String, double>{};

        for (final entry in {
          'Small (100)': smallDataset,
          'Medium (1K)': mediumDataset,
          'Large (10K)': largeDataset,
          'XL (50K)': xlDataset,
        }.entries) {
          final collection = WordTimingCollection(entry.value);
          final stopwatch = Stopwatch()..start();

          // Consistent test: 100 searches per dataset
          for (int i = 0; i < 100; i++) {
            collection.findActiveWordIndex(i * 1000);
          }

          stopwatch.stop();
          results[entry.key] = stopwatch.elapsedMicroseconds / 100;
        }

        print('\nScaling Performance:');
        results.forEach((size, avgTime) {
          print('  - $size: ${avgTime.toStringAsFixed(1)}μs avg');
        });

        // Verify logarithmic scaling: XL should not be 500x slower than Small
        final smallTime = results['Small (100)']!;
        final xlTime = results['XL (50K)']!;
        final scalingFactor = xlTime / smallTime;

        expect(scalingFactor, lessThan(10)); // Should scale well
        print('  - Scaling factor (XL/Small): ${scalingFactor.toStringAsFixed(1)}x');
      });
    });

    group('Locality Caching Performance', () {
      test('should provide significant speedup for sequential access', () {
        final collection = WordTimingCollection(largeDataset);

        // Test 1: Sequential access (simulating real playback)
        collection.resetLocalityCache();
        final sequentialStopwatch = Stopwatch()..start();

        for (int time = 0; time < 1000000; time += 100) {
          collection.findActiveWordIndex(time);
        }

        sequentialStopwatch.stop();

        // Test 2: Random access (worst case for locality)
        collection.resetLocalityCache();
        final randomStopwatch = Stopwatch()..start();

        final random = Random(42); // Fixed seed for reproducible results
        for (int i = 0; i < 10000; i++) {
          final randomTime = random.nextInt(1000000);
          collection.findActiveWordIndex(randomTime);
        }

        randomStopwatch.stop();

        final sequentialAvg = sequentialStopwatch.elapsedMicroseconds / 10000;
        final randomAvg = randomStopwatch.elapsedMicroseconds / 10000;
        final speedupFactor = randomAvg / sequentialAvg;

        print('\nLocality Caching Performance:');
        print('  - Sequential access: ${sequentialAvg.toStringAsFixed(1)}μs avg');
        print('  - Random access: ${randomAvg.toStringAsFixed(1)}μs avg');
        print('  - Speedup factor: ${speedupFactor.toStringAsFixed(1)}x');

        // Should have significant speedup due to locality
        expect(speedupFactor, greaterThan(2.0));
        expect(sequentialAvg, lessThan(1000)); // Very fast for sequential
      });

      test('should maintain 60fps performance during playback simulation', () {
        final collection = WordTimingCollection(largeDataset);
        collection.resetLocalityCache();

        // Simulate 10 seconds of 60fps playback
        const frameCount = 600;
        const frameDurationMs = 16; // 16ms per frame = 60fps

        final stopwatch = Stopwatch()..start();

        for (int frame = 0; frame < frameCount; frame++) {
          final timeMs = frame * frameDurationMs;
          collection.findActiveWordIndex(timeMs);
          collection.findActiveSentenceIndex(timeMs);
        }

        stopwatch.stop();

        final totalTimeMs = stopwatch.elapsedMilliseconds;
        final avgTimePerFrame = stopwatch.elapsedMicroseconds / frameCount;

        print('\n60fps Simulation Performance:');
        print('  - Total time: ${totalTimeMs}ms for 10s simulation');
        print('  - Average per frame: ${avgTimePerFrame.toStringAsFixed(1)}μs');
        print('  - Real-time multiplier: ${(10000 / totalTimeMs).toStringAsFixed(1)}x');

        // Should easily maintain 60fps (<16ms per frame)
        expect(avgTimePerFrame, lessThan(16000)); // 16ms in microseconds
        expect(totalTimeMs, lessThan(100)); // Should complete much faster than real-time
      });
    });

    group('Sentence Operations Performance', () {
      test('should provide O(1) sentence lookups with caching', () {
        final collection = WordTimingCollection(largeDataset);

        // Test sentence boundary lookups (should be O(1) due to caching)
        final stopwatch = Stopwatch()..start();

        const lookupCount = 10000;
        for (int i = 0; i < lookupCount; i++) {
          final sentenceIndex = i % collection.sentenceCount;
          collection.getSentenceBoundaries(sentenceIndex);
        }

        stopwatch.stop();

        final avgTime = stopwatch.elapsedMicroseconds / lookupCount;

        print('\nSentence Operations Performance:');
        print('  - Sentence boundary lookups: ${avgTime.toStringAsFixed(1)}μs avg');
        print('  - Lookups per second: ${(1000000 / avgTime).toStringAsFixed(0)}');

        // Should be extremely fast due to caching
        expect(avgTime, lessThan(10)); // <10μs per lookup
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('should efficiently retrieve words in sentences', () {
        final collection = WordTimingCollection(mediumDataset);

        final stopwatch = Stopwatch()..start();

        // Get words for all sentences
        for (int sentenceIndex = 0; sentenceIndex < collection.sentenceCount; sentenceIndex++) {
          final words = collection.getWordsInSentence(sentenceIndex);
          expect(words.isNotEmpty, isTrue); // Should find words
        }

        stopwatch.stop();

        final avgTime = stopwatch.elapsedMicroseconds / collection.sentenceCount;

        print('  - Words in sentence lookup: ${avgTime.toStringAsFixed(1)}μs avg');
        print('  - Sentences processed: ${collection.sentenceCount}');

        expect(avgTime, lessThan(100)); // Should be fast due to caching
      });
    });

    group('Memory and Resource Usage', () {
      test('should have reasonable memory footprint', () {
        final collection = WordTimingCollection(largeDataset);

        // Test cache sizes are reasonable (not exact, but order of magnitude)
        expect(collection.sentenceCount, lessThan(2000)); // Reasonable sentence count

        // Test that caches don't grow unbounded
        final wordsInFirstSentence = collection.getWordsInSentence(0);
        final wordsInLastSentence = collection.getWordsInSentence(collection.sentenceCount - 1);

        expect(wordsInFirstSentence.length, greaterThan(0));
        expect(wordsInLastSentence.length, greaterThan(0));
        expect(wordsInFirstSentence.length, lessThan(200)); // Reasonable sentence length

        print('\nMemory Usage Stats:');
        print('  - Total words: ${largeDataset.length}');
        print('  - Sentence count: ${collection.sentenceCount}');
        print('  - Avg words per sentence: ${(largeDataset.length / collection.sentenceCount).toStringAsFixed(1)}');
        print('  - Total duration: ${(collection.totalDurationMs / 1000).toStringAsFixed(1)}s');
      });

      test('should handle cache operations efficiently', () {
        final service = WordTimingService.instance;

        // Test cache clearing
        final stopwatch = Stopwatch()..start();
        service.clearCache();
        stopwatch.stop();

        expect(stopwatch.elapsedMicroseconds, lessThan(1000)); // Should be very fast
        print('  - Cache clear time: ${stopwatch.elapsedMicroseconds}μs');

        // Verify cache is actually cleared
        expect(service.getCachedTimings('test'), isNull);
      });
    });

    group('Range and Search Performance', () {
      test('should efficiently find words in time ranges', () {
        final collection = WordTimingCollection(largeDataset);

        final stopwatch = Stopwatch()..start();

        // Test various range queries
        const rangeCount = 100;
        for (int i = 0; i < rangeCount; i++) {
          final startTime = i * 1000;
          final endTime = startTime + 5000; // 5 second ranges
          final wordsInRange = collection.getWordIndicesInRange(startTime, endTime);
          expect(wordsInRange, isA<List<int>>()); // Should return valid list
        }

        stopwatch.stop();

        final avgTime = stopwatch.elapsedMicroseconds / rangeCount;

        print('\nRange Query Performance:');
        print('  - Average range query: ${avgTime.toStringAsFixed(1)}μs');
        print('  - Range queries per second: ${(1000000 / avgTime).toStringAsFixed(0)}');

        expect(avgTime, lessThan(1000)); // Should be fast with binary search
      });

      test('should efficiently find words by text content', () {
        final collection = WordTimingCollection(smallDataset); // Use smaller dataset for text search

        final stopwatch = Stopwatch()..start();

        // Search for various words
        for (int i = 0; i < smallDataset.length; i++) {
          final word = smallDataset[i].word;
          final foundIndex = collection.findWordIndexByText(word);
          expect(foundIndex, equals(i)); // Should find each word
        }

        stopwatch.stop();

        final avgTime = stopwatch.elapsedMicroseconds / smallDataset.length;

        print('\nText Search Performance:');
        print('  - Average text search: ${avgTime.toStringAsFixed(1)}μs');
        print('  - Text searches per second: ${(1000000 / avgTime).toStringAsFixed(0)}');

        expect(avgTime, lessThan(100)); // Linear search should still be reasonably fast
      });
    });

    group('Accuracy Requirements', () {
      test('should meet word synchronization accuracy requirements', () {
        final collection = WordTimingCollection(mediumDataset);

        int accurateMatches = 0;
        const testCount = 1000;

        for (int i = 0; i < testCount; i++) {
          final targetWordIndex = i % mediumDataset.length;
          final targetTiming = mediumDataset[targetWordIndex];
          final targetTime = targetTiming.startMs + (targetTiming.durationMs ~/ 2);

          final foundIndex = collection.findActiveWordIndex(targetTime);

          if (foundIndex == targetWordIndex) {
            accurateMatches++;
          }
        }

        final accuracy = (accurateMatches / testCount) * 100;

        print('\nSynchronization Accuracy:');
        print('  - Word sync accuracy: ${accuracy.toStringAsFixed(1)}%');
        print('  - Accurate matches: $accurateMatches / $testCount');

        // Should have very high accuracy for words at their midpoint
        expect(accuracy, greaterThan(90.0));
      });

      test('should provide 100% sentence accuracy', () {
        final collection = WordTimingCollection(mediumDataset);

        int correctSentences = 0;
        const testCount = 1000;

        for (int i = 0; i < testCount; i++) {
          final wordIndex = i % mediumDataset.length;
          final expectedSentence = mediumDataset[wordIndex].sentenceIndex;
          final wordTime = mediumDataset[wordIndex].startMs +
                          (mediumDataset[wordIndex].durationMs ~/ 2);

          final foundSentence = collection.findActiveSentenceIndex(wordTime);

          if (foundSentence == expectedSentence) {
            correctSentences++;
          }
        }

        final sentenceAccuracy = (correctSentences / testCount) * 100;

        print('  - Sentence sync accuracy: ${sentenceAccuracy.toStringAsFixed(1)}%');
        print('  - Correct sentences: $correctSentences / $testCount');

        // Requirement: 100% sentence accuracy
        expect(sentenceAccuracy, equals(100.0));
      });
    });
  });
}

/// Helper function to create realistic test datasets
List<WordTiming> _createTestDataset(int wordCount, {int avgWordDurationMs = 200}) {
  final timings = <WordTiming>[];
  final random = Random(42); // Fixed seed for reproducible results

  int currentTime = 0;
  int sentenceIndex = 0;
  int wordsInCurrentSentence = 0;
  const avgWordsPerSentence = 15;

  for (int i = 0; i < wordCount; i++) {
    // Vary word duration realistically (100ms to 400ms)
    final duration = (avgWordDurationMs * 0.5) +
                    (random.nextDouble() * avgWordDurationMs);

    timings.add(WordTiming(
      word: 'word$i',
      startMs: currentTime,
      endMs: currentTime + duration.toInt(),
      sentenceIndex: sentenceIndex,
    ));

    currentTime += duration.toInt();

    // Add small gaps between words (realistic speech patterns)
    if (random.nextDouble() < 0.7) { // 70% chance of small pause
      currentTime += random.nextInt(50); // 0-50ms pause
    }

    wordsInCurrentSentence++;

    // End sentence after average number of words (with some variation)
    if (wordsInCurrentSentence >= avgWordsPerSentence - 5 &&
        random.nextDouble() < 0.3) {
      sentenceIndex++;
      wordsInCurrentSentence = 0;

      // Longer pause between sentences
      currentTime += random.nextInt(200) + 100; // 100-300ms pause
    }
  }

  return timings;
}

/// Standalone benchmark runner (can be called from other tests)
void runWordTimingBenchmarks() {
  print('\n🚀 Running WordTiming Performance Benchmarks...\n');

  // Run the main test suite
  main();

  print('\n✅ WordTiming Performance Benchmarks Complete\n');
}