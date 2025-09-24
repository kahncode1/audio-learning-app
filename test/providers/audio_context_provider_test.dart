import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_learning_app/providers/audio_context_provider.dart';
import 'package:audio_learning_app/models/learning_object_v2.dart';
import '../test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Context Provider', () {
    late ProviderContainer container;
    late LearningObjectV2 testLearningObject;

    setUp(() {
      container = ProviderContainer();
      testLearningObject = TestData.createTestLearningObjectV2(
        id: 'test-lo',
        assignmentId: 'test-assignment',
        title: 'Test Learning Object',
        orderIndex: 0,
        isCompleted: false,
        currentPositionMs: 0,
      );
    });

    tearDown(() {
      container.dispose();
    });

    group('AudioContext Model', () {
      test('should create audio context with required learning object', () {
        final context = AudioContext(learningObject: testLearningObject);

        expect(context.learningObject, testLearningObject);
        expect(context.courseNumber, isNull);
        expect(context.courseTitle, isNull);
        expect(context.assignmentTitle, isNull);
        expect(context.assignmentNumber, isNull);
      });

      test('should create audio context with all fields', () {
        final context = AudioContext(
          courseNumber: 'INS-101',
          courseTitle: 'Insurance Fundamentals',
          assignmentTitle: 'Case Studies',
          assignmentNumber: 3,
          learningObject: testLearningObject,
        );

        expect(context.learningObject, testLearningObject);
        expect(context.courseNumber, 'INS-101');
        expect(context.courseTitle, 'Insurance Fundamentals');
        expect(context.assignmentTitle, 'Case Studies');
        expect(context.assignmentNumber, 3);
      });

      test(
          'should generate formatted subtitle with course and assignment number',
          () {
        final context = AudioContext(
          courseNumber: 'INS-101',
          assignmentNumber: 3,
          learningObject: testLearningObject,
        );

        expect(context.formattedSubtitle, 'INS-101 • Assignment 3');
      });

      test('should generate formatted subtitle with course only', () {
        final context = AudioContext(
          courseNumber: 'BUS-200',
          learningObject: testLearningObject,
        );

        expect(context.formattedSubtitle, 'BUS-200');
      });

      test('should generate formatted subtitle with assignment number only',
          () {
        final context = AudioContext(
          assignmentNumber: 5,
          learningObject: testLearningObject,
        );

        expect(context.formattedSubtitle, 'Assignment 5');
      });

      test('should use assignment title when number not available', () {
        final context = AudioContext(
          assignmentTitle: 'Final Project',
          learningObject: testLearningObject,
        );

        expect(context.formattedSubtitle, 'Final Project');
      });

      test('should prefer assignment number over title', () {
        final context = AudioContext(
          assignmentTitle: 'Final Project',
          assignmentNumber: 7,
          learningObject: testLearningObject,
        );

        expect(context.formattedSubtitle, 'Assignment 7');
      });

      test('should use fallback when no context available', () {
        final context = AudioContext(learningObject: testLearningObject);
        expect(context.formattedSubtitle, 'Learning Module');
      });

      test('should handle empty strings gracefully', () {
        final context = AudioContext(
          courseNumber: '',
          assignmentTitle: '',
          learningObject: testLearningObject,
        );

        expect(context.formattedSubtitle, 'Learning Module');
      });

      test('should combine multiple context elements', () {
        final context = AudioContext(
          courseNumber: 'MATH-101',
          assignmentNumber: 2,
          learningObject: testLearningObject,
        );

        expect(context.formattedSubtitle, 'MATH-101 • Assignment 2');
      });
    });

    group('AudioContext copyWith', () {
      test('should create copy with updated learning object', () {
        final originalContext = AudioContext(
          courseNumber: 'TEST-101',
          learningObject: testLearningObject,
        );

        final newLearningObject = TestData.createTestLearningObjectV2(
          id: 'new-lo',
          assignmentId: 'new-assignment',
          title: 'New Learning Object',
          orderIndex: 1,
          isCompleted: false,
          currentPositionMs: 0,
        );

        final updatedContext = originalContext.copyWith(
          learningObject: newLearningObject,
        );

        expect(updatedContext.learningObject, newLearningObject);
        expect(updatedContext.courseNumber, 'TEST-101'); // Preserved
      });

      test('should create copy with updated course information', () {
        final originalContext = AudioContext(
          courseNumber: 'OLD-101',
          courseTitle: 'Old Course',
          learningObject: testLearningObject,
        );

        final updatedContext = originalContext.copyWith(
          courseNumber: 'NEW-202',
          courseTitle: 'New Course',
        );

        expect(updatedContext.courseNumber, 'NEW-202');
        expect(updatedContext.courseTitle, 'New Course');
        expect(updatedContext.learningObject, testLearningObject); // Preserved
      });

      test('should create copy with updated assignment information', () {
        final originalContext = AudioContext(
          assignmentTitle: 'Old Assignment',
          assignmentNumber: 1,
          learningObject: testLearningObject,
        );

        final updatedContext = originalContext.copyWith(
          assignmentTitle: 'New Assignment',
          assignmentNumber: 5,
        );

        expect(updatedContext.assignmentTitle, 'New Assignment');
        expect(updatedContext.assignmentNumber, 5);
        expect(updatedContext.learningObject, testLearningObject); // Preserved
      });

      test('should preserve original values when not specified', () {
        final originalContext = AudioContext(
          courseNumber: 'PRESERVE-101',
          courseTitle: 'Preserve Course',
          assignmentTitle: 'Preserve Assignment',
          assignmentNumber: 3,
          learningObject: testLearningObject,
        );

        final updatedContext = originalContext.copyWith(
          courseTitle: 'Updated Course',
        );

        expect(updatedContext.courseNumber, 'PRESERVE-101'); // Preserved
        expect(updatedContext.courseTitle, 'Updated Course'); // Updated
        expect(
            updatedContext.assignmentTitle, 'Preserve Assignment'); // Preserved
        expect(updatedContext.assignmentNumber, 3); // Preserved
        expect(updatedContext.learningObject, testLearningObject); // Preserved
      });
    });

    group('audioContextProvider', () {
      test('should start with null value', () {
        final audioContext = container.read(audioContextProvider);
        expect(audioContext, isNull);
      });

      test('should update audio context', () {
        final context = AudioContext(
          courseNumber: 'TEST-101',
          learningObject: testLearningObject,
        );

        container.read(audioContextProvider.notifier).state = context;

        final audioContext = container.read(audioContextProvider);
        expect(audioContext, context);
        expect(audioContext!.courseNumber, 'TEST-101');
        expect(audioContext.learningObject, testLearningObject);
      });

      test('should allow clearing audio context', () {
        final context = AudioContext(learningObject: testLearningObject);

        // Set context
        container.read(audioContextProvider.notifier).state = context;
        expect(container.read(audioContextProvider), isNotNull);

        // Clear context
        container.read(audioContextProvider.notifier).state = null;
        expect(container.read(audioContextProvider), isNull);
      });

      test('should notify listeners when context changes', () {
        var notificationCount = 0;

        container.listen(
          audioContextProvider,
          (previous, next) => notificationCount++,
        );

        final context = AudioContext(learningObject: testLearningObject);
        container.read(audioContextProvider.notifier).state = context;

        expect(notificationCount, 1);
        expect(container.read(audioContextProvider), context);
      });
    });

    group('miniPlayerSubtitleProvider', () {
      test('should provide fallback subtitle when no context', () {
        final subtitle = container.read(miniPlayerSubtitleProvider);
        expect(subtitle, 'Learning Module');
      });

      test('should provide formatted subtitle from context', () {
        final context = AudioContext(
          courseNumber: 'INS-101',
          assignmentNumber: 2,
          learningObject: testLearningObject,
        );

        container.read(audioContextProvider.notifier).state = context;

        final subtitle = container.read(miniPlayerSubtitleProvider);
        expect(subtitle, 'INS-101 • Assignment 2');
      });

      test('should update when audio context changes', () {
        // Initially fallback
        expect(container.read(miniPlayerSubtitleProvider), 'Learning Module');

        // Set context
        final context = AudioContext(
          courseNumber: 'BUS-200',
          learningObject: testLearningObject,
        );
        container.read(audioContextProvider.notifier).state = context;

        // Should update
        expect(container.read(miniPlayerSubtitleProvider), 'BUS-200');

        // Clear context
        container.read(audioContextProvider.notifier).state = null;

        // Should return to fallback
        expect(container.read(miniPlayerSubtitleProvider), 'Learning Module');
      });

      test('should watch audio context provider', () {
        var notificationCount = 0;

        container.listen(
          miniPlayerSubtitleProvider,
          (previous, next) => notificationCount++,
        );

        final context = AudioContext(
          assignmentNumber: 3,
          learningObject: testLearningObject,
        );
        container.read(audioContextProvider.notifier).state = context;

        expect(notificationCount, 1);
        expect(container.read(miniPlayerSubtitleProvider), 'Assignment 3');
      });
    });

    group('AudioContextHelper', () {
      test('should create context from navigation args', () {
        final navigationArgs = {
          'courseNumber': 'INS-101',
          'courseTitle': 'Insurance Course',
          'assignmentTitle': 'Assignment Title',
          'assignmentNumber': 4,
        };

        final context = AudioContextHelper.fromNavigationArgs(
          navigationArgs,
          testLearningObject,
        );

        expect(context.courseNumber, 'INS-101');
        expect(context.courseTitle, 'Insurance Course');
        expect(context.assignmentTitle, 'Assignment Title');
        expect(context.assignmentNumber, 4);
        expect(context.learningObject, testLearningObject);
      });

      test('should handle missing navigation args', () {
        final navigationArgs = <String, dynamic>{
          'courseNumber': 'PARTIAL-101',
          // Other fields missing
        };

        final context = AudioContextHelper.fromNavigationArgs(
          navigationArgs,
          testLearningObject,
        );

        expect(context.courseNumber, 'PARTIAL-101');
        expect(context.courseTitle, isNull);
        expect(context.assignmentTitle, isNull);
        expect(context.assignmentNumber, isNull);
        expect(context.learningObject, testLearningObject);
      });

      test('should handle null values in navigation args', () {
        final navigationArgs = <String, dynamic>{
          'courseNumber': null,
          'courseTitle': null,
          'assignmentTitle': 'Valid Title',
          'assignmentNumber': null,
        };

        final context = AudioContextHelper.fromNavigationArgs(
          navigationArgs,
          testLearningObject,
        );

        expect(context.courseNumber, isNull);
        expect(context.courseTitle, isNull);
        expect(context.assignmentTitle, 'Valid Title');
        expect(context.assignmentNumber, isNull);
        expect(context.learningObject, testLearningObject);
      });

      test('should create context from learning object only', () {
        final context =
            AudioContextHelper.fromLearningObject(testLearningObject);

        expect(context.courseNumber, isNull);
        expect(context.courseTitle, isNull);
        expect(context.assignmentTitle, isNull);
        expect(context.assignmentNumber, isNull);
        expect(context.learningObject, testLearningObject);
        expect(context.formattedSubtitle, 'Learning Module');
      });

      test('should handle type casting in navigation args', () {
        final navigationArgs = <String, dynamic>{
          'courseNumber': 'TEST-101',
          'assignmentNumber': 5, // int
          'assignmentTitle': 'Test Assignment', // string
        };

        final context = AudioContextHelper.fromNavigationArgs(
          navigationArgs,
          testLearningObject,
        );

        expect(context.courseNumber, isA<String>());
        expect(context.assignmentNumber, isA<int>());
        expect(context.assignmentTitle, isA<String>());
        expect(context.assignmentNumber, 5);
      });
    });

    group('Provider Integration', () {
      test('should work with provider lifecycle', () {
        final testContainer = ProviderContainer();

        final context = AudioContext(
          courseNumber: 'LIFECYCLE-101',
          learningObject: testLearningObject,
        );

        testContainer.read(audioContextProvider.notifier).state = context;
        expect(testContainer.read(audioContextProvider), context);
        expect(testContainer.read(miniPlayerSubtitleProvider), 'LIFECYCLE-101');

        testContainer.dispose();
      });

      test('should handle provider recreation', () {
        final testContainer = ProviderContainer();
        final context1 = testContainer.read(audioContextProvider);
        testContainer.dispose();

        final newContainer = ProviderContainer();
        final context2 = newContainer.read(audioContextProvider);

        // Should start fresh with null
        expect(context1, isNull);
        expect(context2, isNull);
        newContainer.dispose();
      });
    });

    group('Edge Cases', () {
      test('should handle extremely long context strings', () {
        final longCourseNumber = 'A' * 100;
        final longAssignmentTitle = 'B' * 200;

        final context = AudioContext(
          courseNumber: longCourseNumber,
          assignmentTitle: longAssignmentTitle,
          learningObject: testLearningObject,
        );

        // Should not throw
        final subtitle = context.formattedSubtitle;
        expect(subtitle, isA<String>());
        expect(subtitle, contains(longCourseNumber));
        expect(subtitle, contains(longAssignmentTitle));
      });

      test('should handle special characters in context', () {
        final context = AudioContext(
          courseNumber: 'TEST-101 (Special)',
          assignmentTitle: 'Assignment & Project',
          learningObject: testLearningObject,
        );

        final subtitle = context.formattedSubtitle;
        expect(subtitle, contains('TEST-101 (Special)'));
        expect(subtitle, contains('Assignment & Project'));
        expect(subtitle, contains(' • '));
      });

      test('should handle numeric assignment titles', () {
        final navigationArgs = <String, dynamic>{
          'assignmentNumber': 42,
          'assignmentTitle': '123456', // Numeric string
        };

        final context = AudioContextHelper.fromNavigationArgs(
          navigationArgs,
          testLearningObject,
        );

        // Should prefer number over title
        expect(context.formattedSubtitle, 'Assignment 42');
      });
    });

    group('State Consistency', () {
      test('should maintain state across multiple updates', () {
        final context1 = AudioContext(
          courseNumber: 'FIRST-101',
          learningObject: testLearningObject,
        );

        final context2 = AudioContext(
          courseNumber: 'SECOND-202',
          assignmentNumber: 1,
          learningObject: testLearningObject,
        );

        container.read(audioContextProvider.notifier).state = context1;
        expect(container.read(miniPlayerSubtitleProvider), 'FIRST-101');

        container.read(audioContextProvider.notifier).state = context2;
        expect(container.read(miniPlayerSubtitleProvider),
            'SECOND-202 • Assignment 1');

        container.read(audioContextProvider.notifier).state = null;
        expect(container.read(miniPlayerSubtitleProvider), 'Learning Module');
      });
    });
  });
}
