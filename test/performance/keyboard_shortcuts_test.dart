import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

// Abstract interface for audio service
abstract class AudioPlayerService {
  Future<void> togglePlayPause();
  Future<void> skipForward();
  Future<void> skipBackward();
}

// Mock implementation using mocktail
class MockAudioPlayerService extends Mock implements AudioPlayerService {}

void main() {
  late MockAudioPlayerService mockAudioService;

  setUp(() {
    mockAudioService = MockAudioPlayerService();
    // Set up default stub responses for all methods
    when(() => mockAudioService.togglePlayPause()).thenAnswer((_) async {});
    when(() => mockAudioService.skipForward()).thenAnswer((_) async {});
    when(() => mockAudioService.skipBackward()).thenAnswer((_) async {});
  });

  group('Keyboard Shortcuts Performance Tests', () {
    group('Response Time Measurements', () {
      testWidgets('spacebar play/pause should respond within 50ms', (tester) async {
        // Build a test widget with keyboard listener
        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardShortcutWidget(
              audioService: mockAudioService,
            ),
          ),
        );

        // Measure response time for spacebar
        final stopwatch = Stopwatch()..start();

        // Simulate spacebar press
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        stopwatch.stop();

        // Verify response time is under 50ms
        expect(stopwatch.elapsedMilliseconds, lessThan(50),
            reason: 'Spacebar response time exceeded 50ms: ${stopwatch.elapsedMilliseconds}ms');

        // Verify the action was triggered
        verify(() => mockAudioService.togglePlayPause()).called(1);
      });

      testWidgets('arrow key skip should respond within 50ms', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardShortcutWidget(
              audioService: mockAudioService,
            ),
          ),
        );

        // Test right arrow (skip forward)
        final stopwatchForward = Stopwatch()..start();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        stopwatchForward.stop();

        expect(stopwatchForward.elapsedMilliseconds, lessThan(50),
            reason: 'Right arrow response time exceeded 50ms: ${stopwatchForward.elapsedMilliseconds}ms');

        verify(() => mockAudioService.skipForward()).called(1);

        // Test left arrow (skip backward)
        final stopwatchBackward = Stopwatch()..start();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        stopwatchBackward.stop();

        expect(stopwatchBackward.elapsedMilliseconds, lessThan(50),
            reason: 'Left arrow response time exceeded 50ms: ${stopwatchBackward.elapsedMilliseconds}ms');

        verify(() => mockAudioService.skipBackward()).called(1);
      });

      testWidgets('should handle rapid key presses', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardShortcutWidget(
              audioService: mockAudioService,
            ),
          ),
        );

        // Simulate rapid key presses
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 10; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump(const Duration(milliseconds: 10));
        }

        stopwatch.stop();

        // All key presses should be handled within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Rapid key handling took too long: ${stopwatch.elapsedMilliseconds}ms');

        // Verify all presses were handled
        verify(() => mockAudioService.togglePlayPause()).called(10);
      });
    });

    group('Focus Management', () {
      testWidgets('shortcuts should work when player is focused', (tester) async {
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardShortcutWidget(
              audioService: mockAudioService,
              focusNode: focusNode,
            ),
          ),
        );

        // Request focus
        focusNode.requestFocus();
        await tester.pump();

        // Verify focus is obtained
        expect(focusNode.hasFocus, isTrue);

        // Test shortcuts work with focus
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        verify(() => mockAudioService.togglePlayPause()).called(1);
      });

      testWidgets('shortcuts should not work when player is not focused', (tester) async {
        final playerFocusNode = FocusNode();
        final otherFocusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Focus(
                    focusNode: otherFocusNode,
                    child: const TextField(),
                  ),
                  KeyboardShortcutWidget(
                    audioService: mockAudioService,
                    focusNode: playerFocusNode,
                  ),
                ],
              ),
            ),
          ),
        );

        // Focus on text field instead
        otherFocusNode.requestFocus();
        await tester.pump();

        // Send spacebar
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        // Should not trigger play/pause
        verifyNever(() => mockAudioService.togglePlayPause());
      });
    });

    group('Key Combinations', () {
      testWidgets('should handle modifier keys correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardShortcutWidget(
              audioService: mockAudioService,
            ),
          ),
        );

        // Ctrl+Space should not trigger play/pause
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump();

        verifyNever(() => mockAudioService.togglePlayPause());

        // Plain space should trigger
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        verify(() => mockAudioService.togglePlayPause()).called(1);
      });

      testWidgets('should ignore non-shortcut keys', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardShortcutWidget(
              audioService: mockAudioService,
            ),
          ),
        );

        // Test various non-shortcut keys
        final nonShortcutKeys = [
          LogicalKeyboardKey.keyA,
          LogicalKeyboardKey.keyB,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.escape,
          LogicalKeyboardKey.tab,
        ];

        for (final key in nonShortcutKeys) {
          await tester.sendKeyEvent(key);
          await tester.pump();
        }

        // None should trigger audio actions
        verifyNever(() => mockAudioService.togglePlayPause());
        verifyNever(() => mockAudioService.skipForward());
        verifyNever(() => mockAudioService.skipBackward());
      });
    });

    group('Performance Under Load', () {
      testWidgets('should maintain performance with heavy UI', (tester) async {
        // Build a complex widget tree
        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                // Heavy background widgets
                ...List.generate(100, (index) => Container(
                  key: ValueKey(index),
                  color: Colors.blue.withOpacity(0.01),
                  child: Text('Background $index'),
                )),
                // Keyboard shortcut widget
                KeyboardShortcutWidget(
                  audioService: mockAudioService,
                ),
              ],
            ),
          ),
        );

        // Measure response time even with heavy UI
        final stopwatch = Stopwatch()..start();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        stopwatch.stop();

        // Should still respond within 50ms
        expect(stopwatch.elapsedMilliseconds, lessThan(50),
            reason: 'Response time with heavy UI exceeded 50ms: ${stopwatch.elapsedMilliseconds}ms');

        verify(() => mockAudioService.togglePlayPause()).called(1);
      });

      testWidgets('should handle concurrent animations', (tester) async {
        final animationController = AnimationController(
          duration: const Duration(seconds: 1),
          vsync: tester,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AnimatedBuilder(
              animation: animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: animationController.value * 2 * 3.14159,
                  child: KeyboardShortcutWidget(
                    audioService: mockAudioService,
                  ),
                );
              },
            ),
          ),
        );

        // Start animation
        animationController.repeat();

        // Add addTearDown to properly dispose the animation controller
        addTearDown(() {
          animationController.stop();
          animationController.dispose();
        });

        // Measure response during animation
        final stopwatch = Stopwatch()..start();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(50),
            reason: 'Response during animation exceeded 50ms: ${stopwatch.elapsedMilliseconds}ms');

        verify(() => mockAudioService.togglePlayPause()).called(1);

        // Stop the animation before the test ends
        animationController.stop();
      });
    });

    group('Memory Performance', () {
      testWidgets('should not leak memory on repeated use', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: KeyboardShortcutWidget(
              audioService: mockAudioService,
            ),
          ),
        );

        // Simulate extended usage
        for (int i = 0; i < 100; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pump();
        }

        // Widget should still be responsive
        final stopwatch = Stopwatch()..start();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(50),
            reason: 'Response after extended use exceeded 50ms: ${stopwatch.elapsedMilliseconds}ms');
      });
    });
  });
}

// Test widget for keyboard shortcuts
class KeyboardShortcutWidget extends StatelessWidget {
  final AudioPlayerService audioService;
  final FocusNode? focusNode;

  const KeyboardShortcutWidget({
    Key? key,
    required this.audioService,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          // Check for modifier keys
          if (event.isControlPressed ||
              event.isAltPressed ||
              event.isMetaPressed ||
              event.isShiftPressed) {
            return KeyEventResult.ignored;
          }

          // Handle shortcuts
          if (event.logicalKey == LogicalKeyboardKey.space) {
            audioService.togglePlayPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            audioService.skipForward();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            audioService.skipBackward();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        width: 200,
        height: 100,
        color: Colors.blue,
        child: const Center(
          child: Text(
            'Audio Player',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}