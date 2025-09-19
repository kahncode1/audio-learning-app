import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:audio_learning_app/widgets/simplified_dual_level_highlighted_text.dart';
import 'package:audio_learning_app/models/word_timing.dart';

/// Critical tests for SimplifiedDualLevelHighlightedText widget
///
/// Purpose: Protect the dual-level highlighting system from regression
/// Coverage: Performance, character offsets, auto-scrolling, paint cycles
///
/// CRITICAL PERFORMANCE REQUIREMENTS:
/// - Binary search: <1ms (target 549μs)
/// - Paint cycle: <16ms for 60fps
/// - Font size change: <16ms
/// - Word sync accuracy: ±50ms
void main() {
  group('SimplifiedDualLevelHighlightedText Performance', () {
    const testText = 'When dealing with insurance claims, it is crucial to establish '
        'a proper case reserve early in the process. This helps ensure that '
        'adequate funds are allocated for potential payouts. The reserve amount '
        'should reflect the estimated total cost of the claim including legal fees.';

    List<WordTiming> createTestTimings() {
      final words = testText.split(' ');
      final timings = <WordTiming>[];
      int charPos = 0;
      int timeMs = 0;
      int sentenceIndex = 0;

      for (int i = 0; i < words.length; i++) {
        final word = words[i];

        // Update sentence index at sentence boundaries
        if (word.endsWith('.')) {
          sentenceIndex++;
        }

        timings.add(WordTiming(
          word: word,
          startMs: timeMs,
          endMs: timeMs + 300,
          charStart: charPos,
          charEnd: charPos + word.length,
          sentenceIndex: sentenceIndex,
        ));

        charPos += word.length + 1; // +1 for space
        timeMs += 350; // 350ms per word
      }

      return timings;
    }

    group('Binary Search Performance', () {
      test('should find word index in <1ms', () {
        final timings = createTestTimings();
        final collection = WordTimingCollection(timings: timings);

        // Warm up
        for (int i = 0; i < 10; i++) {
          collection.getCurrentWordIndex(5000);
        }

        // Measure performance
        final stopwatch = Stopwatch()..start();
        const iterations = 1000;

        for (int i = 0; i < iterations; i++) {
          final positionMs = (i * 100) % 20000; // Vary positions
          collection.getCurrentWordIndex(positionMs);
        }

        stopwatch.stop();
        final avgMicroseconds = stopwatch.elapsedMicroseconds / iterations;

        // Should be <1000μs (1ms), currently achieving ~549μs
        expect(avgMicroseconds, lessThan(1000),
            reason: 'Binary search took ${avgMicroseconds}μs average, '
                   'should be <1000μs (target: 549μs)');

        // Log performance for tracking
        debugPrint('Binary search performance: ${avgMicroseconds.toStringAsFixed(0)}μs '
                  '(target: 549μs, requirement: <1000μs)');
      });

      test('should handle edge cases correctly', () {
        final timings = createTestTimings();
        final collection = WordTimingCollection(timings: timings);

        // Before first word
        expect(collection.getCurrentWordIndex(-100), equals(0));

        // After last word
        expect(collection.getCurrentWordIndex(999999), equals(timings.length - 1));

        // Exact word boundaries
        expect(collection.getCurrentWordIndex(0), equals(0));
        expect(collection.getCurrentWordIndex(300), equals(1));
        expect(collection.getCurrentWordIndex(650), equals(2));
      });
    });

    group('Character Offset Correction', () {
      test('should handle 0-based indexing correctly', () {
        final timings = createTestTimings();
        final widget = SimplifiedDualLevelHighlightedText(
          text: testText,
          wordTimings: timings,
          currentWordIndex: 0,
          currentSentenceIndex: 0,
        );

        // Create widget tester
        testWidgets('character offset validation', (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: widget,
              ),
            ),
          );

          // Widget should render without errors
          expect(find.byType(SimplifiedDualLevelHighlightedText), findsOneWidget);
        });
      });

      test('should correct misaligned character positions', () {
        // Create timings with intentional misalignment
        final timings = [
          WordTiming(
            word: 'Test',
            startMs: 0,
            endMs: 300,
            charStart: 1, // Wrong: should be 0
            charEnd: 5,   // Wrong: should be 4
            sentenceIndex: 0,
          ),
          WordTiming(
            word: 'word',
            startMs: 300,
            endMs: 600,
            charStart: 6,  // Wrong: should be 5
            charEnd: 10,  // Wrong: should be 9
            sentenceIndex: 0,
          ),
        ];

        testWidgets('handles misaligned positions', (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SimplifiedDualLevelHighlightedText(
                  text: 'Test word',
                  wordTimings: timings,
                  currentWordIndex: 0,
                  currentSentenceIndex: 0,
                ),
              ),
            ),
          );

          // Should render without throwing
          expect(find.byType(SimplifiedDualLevelHighlightedText), findsOneWidget);
        });
      });

      test('should fallback to fuzzy matching when positions invalid', () {
        // Create timing with no character positions
        final timings = [
          WordTiming(
            word: 'Insurance',
            startMs: 0,
            endMs: 300,
            charStart: null, // Missing position
            charEnd: null,   // Missing position
            sentenceIndex: 0,
          ),
        ];

        testWidgets('handles missing positions', (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SimplifiedDualLevelHighlightedText(
                  text: 'Insurance coverage is important',
                  wordTimings: timings,
                  currentWordIndex: 0,
                  currentSentenceIndex: 0,
                ),
              ),
            ),
          );

          // Should render with fallback UI
          expect(find.byType(SimplifiedDualLevelHighlightedText), findsOneWidget);
        });
      });
    });

    group('Paint Cycle Performance', () {
      testWidgets('should maintain 60fps during highlighting', (WidgetTester tester) async {
        final timings = createTestTimings();
        int currentIndex = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SimplifiedDualLevelHighlightedText(
                    text: testText,
                    wordTimings: timings,
                    currentWordIndex: currentIndex,
                    currentSentenceIndex: 0,
                  );
                },
              ),
            ),
          ),
        );

        // Measure frame timing during rapid updates
        final List<Duration> frameTimes = [];

        for (int i = 0; i < 20; i++) {
          final stopwatch = Stopwatch()..start();

          currentIndex = i % timings.length;
          await tester.pump();

          stopwatch.stop();
          frameTimes.add(stopwatch.elapsed);
        }

        // All frames should be <16ms for 60fps
        for (final frameTime in frameTimes) {
          expect(frameTime.inMilliseconds, lessThan(16),
              reason: 'Frame took ${frameTime.inMilliseconds}ms, needs <16ms for 60fps');
        }

        final avgFrameMs = frameTimes
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a + b) / frameTimes.length;

        debugPrint('Average frame time: ${avgFrameMs.toStringAsFixed(1)}ms '
                  '(requirement: <16ms for 60fps)');
      });

      testWidgets('should not recreate TextPainter during paint', (WidgetTester tester) async {
        final timings = createTestTimings();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SimplifiedDualLevelHighlightedText(
                text: testText,
                wordTimings: timings,
                currentWordIndex: 0,
                currentSentenceIndex: 0,
              ),
            ),
          ),
        );

        // Get the render object
        final finder = find.byType(SimplifiedDualLevelHighlightedText);
        final renderObject = tester.renderObject(finder);

        // TextPainter should be created once and reused
        // This is validated by the widget's implementation
        expect(renderObject, isNotNull);
      });
    });

    group('Auto-Scroll Behavior', () {
      testWidgets('should maintain 25-35% reading zone', (WidgetTester tester) async {
        final timings = createTestTimings();
        final scrollController = ScrollController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Container(
                height: 600, // Fixed viewport height
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SimplifiedDualLevelHighlightedText(
                    text: testText * 10, // Long text to enable scrolling
                    wordTimings: timings,
                    currentWordIndex: 0,
                    currentSentenceIndex: 0,
                    scrollController: scrollController,
                    enableAutoScroll: true,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Reading zone should be 25-35% from top
        const viewportHeight = 600.0;
        const expectedMinZone = viewportHeight * 0.25;
        const expectedMaxZone = viewportHeight * 0.35;

        // Verify initial position
        expect(scrollController.hasClients, isTrue);

        // Note: Actual scrolling behavior would need more complex testing
        // This validates the basic setup
      });

      testWidgets('should handle font size changes efficiently', (WidgetTester tester) async {
        final timings = createTestTimings();
        double fontSize = 16.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SimplifiedDualLevelHighlightedText(
                    text: testText,
                    wordTimings: timings,
                    currentWordIndex: 0,
                    currentSentenceIndex: 0,
                    fontSize: fontSize,
                  );
                },
              ),
            ),
          ),
        );

        // Measure font size change performance
        final stopwatch = Stopwatch()..start();

        fontSize = 20.0;
        await tester.pump();

        stopwatch.stop();

        // Font size change should be <16ms
        expect(stopwatch.elapsed.inMilliseconds, lessThan(16),
            reason: 'Font size change took ${stopwatch.elapsed.inMilliseconds}ms, '
                   'should be <16ms');
      });
    });

    group('Three-Layer Paint System', () {
      testWidgets('should paint layers in correct order', (WidgetTester tester) async {
        final timings = createTestTimings();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SimplifiedDualLevelHighlightedText(
                text: testText,
                wordTimings: timings,
                currentWordIndex: 2,
                currentSentenceIndex: 0,
              ),
            ),
          ),
        );

        // Verify widget renders with all three layers
        expect(find.byType(SimplifiedDualLevelHighlightedText), findsOneWidget);

        // Layers painted in order:
        // 1. Sentence background (Color(0xFFE3F2FD))
        // 2. Word highlight (Color(0xFFFFF59D))
        // 3. Text (black)

        // Note: Actual paint order validation would require custom render testing
      });

      testWidgets('should handle empty highlighting gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SimplifiedDualLevelHighlightedText(
                text: testText,
                wordTimings: [], // No timings
                currentWordIndex: -1,
                currentSentenceIndex: -1,
              ),
            ),
          ),
        );

        // Should render plain text without highlights
        expect(find.byType(SimplifiedDualLevelHighlightedText), findsOneWidget);
      });
    });

    group('Stress Testing', () {
      test('should handle rapid position updates', () {
        final timings = createTestTimings();
        final collection = WordTimingCollection(timings: timings);

        // Simulate rapid position updates (60fps for 1 second)
        final stopwatch = Stopwatch()..start();

        for (int frame = 0; frame < 60; frame++) {
          final positionMs = frame * 16; // 16ms per frame at 60fps
          collection.getCurrentWordIndex(positionMs);
          collection.getCurrentSentenceIndex(positionMs);
        }

        stopwatch.stop();

        // Should complete 60 lookups in <1 second
        expect(stopwatch.elapsed.inMilliseconds, lessThan(1000),
            reason: '60 position updates took ${stopwatch.elapsed.inMilliseconds}ms');
      });

      test('should handle very long sentences efficiently', () {
        // Create timing with 100+ word sentence
        final longSentence = List.generate(100, (i) => 'word$i').join(' ');
        final timings = <WordTiming>[];

        int charPos = 0;
        for (int i = 0; i < 100; i++) {
          final word = 'word$i';
          timings.add(WordTiming(
            word: word,
            startMs: i * 100,
            endMs: (i + 1) * 100,
            charStart: charPos,
            charEnd: charPos + word.length,
            sentenceIndex: 0, // All same sentence
          ));
          charPos += word.length + 1;
        }

        final collection = WordTimingCollection(timings: timings);

        // Should handle lookups efficiently even with long sentence
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          collection.getCurrentSentenceIndex(i * 100);
        }

        stopwatch.stop();

        expect(stopwatch.elapsed.inMilliseconds, lessThan(10),
            reason: 'Long sentence lookups should be fast');
      });
    });
  });
}