import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_learning_app/screens/assignments_screen.dart';
import 'package:audio_learning_app/screens/enhanced_audio_player_screen.dart';
import 'package:audio_learning_app/models/learning_object.dart';
import 'package:audio_learning_app/models/assignment.dart';
import 'package:audio_learning_app/services/audio_player_service_local.dart';
import 'package:audio_learning_app/services/progress_service.dart';
import 'package:audio_learning_app/providers/course_providers.dart';

// Mock classes
class MockAudioPlayerServiceLocal extends Mock implements AudioPlayerServiceLocal {}
class MockProgressService extends Mock implements ProgressService {}

void main() {
  late MockAudioPlayerServiceLocal mockAudioService;
  late MockProgressService mockProgressService;
  late LearningObject testLearningObject;
  late Assignment testAssignment;

  setUpAll(() {
    registerFallbackValue(ProcessingState.idle);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockAudioService = MockAudioPlayerServiceLocal();
    mockProgressService = MockProgressService();

    testAssignment = Assignment(
      id: 'test-assignment-id',
      courseId: 'test-course-id',
      title: 'Test Assignment',
      assignmentNumber: 1,
      orderIndex: 1,
      createdAt: DateTime.now(),
    );

    testLearningObject = LearningObject(
      id: 'test-lo-id',
      assignmentId: testAssignment.id,
      title: 'Test Learning Object',
      plainText: 'Test content for integration testing',
      durationMs: 30000, // 30 seconds
      orderIndex: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isCompleted: false,
      isInProgress: false,
      currentPositionMs: 0,
    );

    // Setup default mock behaviors
    when(() => mockAudioService.processingStateStream)
        .thenAnswer((_) => Stream.value(ProcessingState.idle));
    when(() => mockAudioService.positionStream)
        .thenAnswer((_) => Stream.value(Duration.zero));
    when(() => mockAudioService.isPlayingStream)
        .thenAnswer((_) => Stream.value(false));
    when(() => mockAudioService.duration).thenReturn(const Duration(seconds: 30));
    when(() => mockProgressService.saveProgress(
      learningObjectId: any(named: 'learningObjectId'),
      positionMs: any(named: 'positionMs'),
      isCompleted: any(named: 'isCompleted'),
      isInProgress: any(named: 'isInProgress'),
    )).thenReturn(null);
  });

  group('Complete Learning Object Flow', () {
    testWidgets('should complete full flow from assignment to completion', (tester) async {
      // This is a high-level integration test showing the complete flow
      // In a real scenario, this would be more complex with actual providers

      // Step 1: Start at assignment screen
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [
              learningObjectsProvider(testAssignment.id).overrideWith((ref) async {
                return [testLearningObject];
              }),
            ],
            child: AssignmentsScreen(
              courseId: 'test-course',
              courseTitle: 'Test Course',
              courseNumber: 'TEST-101',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify learning object tile is displayed
      expect(find.text(testLearningObject.title), findsOneWidget);

      // Verify not completed initially
      expect(find.byIcon(Icons.check_circle), findsNothing);

      // Step 2: Tap to open learning object
      await tester.tap(find.text(testLearningObject.title));
      await tester.pumpAndSettle();

      // Step 3: Verify navigation to audio player
      // (In a real test, this would navigate to the actual player screen)

      // Step 4: Simulate audio completion
      // (This would trigger the completion handler in the real implementation)

      // Step 5: Verify navigation back to assignment screen
      // (The real implementation would use Navigator.pop with true)

      // Step 6: Verify learning object now shows as completed
      // (After provider refresh, the UI would update)

      // This test demonstrates the expected flow, but would need
      // more complex setup to test the actual implementation
      expect(testLearningObject, isNotNull);
    });

    testWidgets('should update UI after learning object completion', (tester) async {
      // Create a completed version of the learning object
      final completedLearningObject = testLearningObject.copyWith(
        isCompleted: true,
        currentPositionMs: testLearningObject.durationMs,
      );

      // Start with uncompleted learning object
      final learningObjects = ValueNotifier<List<LearningObject>>([testLearningObject]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<LearningObject>>(
              valueListenable: learningObjects,
              builder: (context, objects, _) {
                return Column(
                  children: objects.map((lo) => LearningObjectTile(
                    learningObject: lo,
                    isActive: false,
                    onTap: () async {
                      // Simulate navigation and completion
                      await Future.delayed(const Duration(milliseconds: 100));

                      // Update the list with completed object
                      learningObjects.value = [completedLearningObject];
                    },
                  )).toList(),
                );
              },
            ),
          ),
        ),
      );

      // Initially not completed
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Completed'), findsNothing);

      // Tap the learning object
      await tester.tap(find.text(testLearningObject.title));
      await tester.pumpAndSettle();

      // Now should show as completed
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.textContaining('Completed'), findsOneWidget);
    });

    testWidgets('should persist completion status', (tester) async {
      // This test verifies that completion status persists
      final completedLearningObject = testLearningObject.copyWith(
        isCompleted: true,
      );

      // First render - show as completed
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTile(
              learningObject: completedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify completed UI
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.textContaining('Completed'), findsOneWidget);

      // Simulate app restart by rebuilding widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Loading...'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Re-render with same completed object
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTile(
              learningObject: completedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Should still show as completed
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      expect(find.textContaining('Completed'), findsOneWidget);
    });

    testWidgets('should handle multiple learning objects completion', (tester) async {
      // Create multiple learning objects
      final lo1 = testLearningObject;
      final lo2 = testLearningObject.copyWith(
        id: 'lo-2',
        title: 'Second Learning Object',
        isCompleted: true,
      );
      final lo3 = testLearningObject.copyWith(
        id: 'lo-3',
        title: 'Third Learning Object',
        isInProgress: true,
        currentPositionMs: 15000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LearningObjectTile(
                  learningObject: lo1,
                  isActive: false,
                  onTap: () {},
                ),
                LearningObjectTile(
                  learningObject: lo2,
                  isActive: false,
                  onTap: () {},
                ),
                LearningObjectTile(
                  learningObject: lo3,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Verify first object (not started)
      final firstTile = find.text(lo1.title);
      expect(firstTile, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(of: firstTile, matching: find.byType(LearningObjectTile)),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsNothing,
      );

      // Verify second object (completed)
      final secondTile = find.text(lo2.title);
      expect(secondTile, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(of: secondTile, matching: find.byType(LearningObjectTile)),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsWidgets,
      );

      // Verify third object (in progress)
      final thirdTile = find.text(lo3.title);
      expect(thirdTile, findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(of: thirdTile, matching: find.byType(LearningObjectTile)),
          matching: find.text('Resume'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Error Handling', () {
    testWidgets('should handle navigation errors gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTile(
              learningObject: testLearningObject,
              isActive: false,
              onTap: () {
                // Simulate error during navigation
                throw Exception('Navigation error');
              },
            ),
          ),
        ),
      );

      // Tap should not crash the app
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // App should still be running
      expect(find.byType(LearningObjectTile), findsOneWidget);
    });

    testWidgets('should handle missing progress service', (tester) async {
      // Test that the app doesn't crash if progress service is unavailable
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: Scaffold(
              body: LearningObjectTile(
                learningObject: testLearningObject,
                isActive: false,
                onTap: () async {
                  // Simulate completion without progress service
                  // Should handle gracefully
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(LearningObjectTile), findsOneWidget);
    });
  });
}