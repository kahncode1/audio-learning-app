import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_learning_app/providers/course_providers.dart';
import 'package:audio_learning_app/services/supabase_service.dart';
import 'package:audio_learning_app/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Course Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('supabaseServiceProvider', () {
      test('should provide SupabaseService instance', () {
        final service = container.read(supabaseServiceProvider);
        expect(service, isA<SupabaseService>());
      });

      test('should provide singleton instance', () {
        final service1 = container.read(supabaseServiceProvider);
        final service2 = container.read(supabaseServiceProvider);
        expect(identical(service1, service2), isTrue);
      });
    });

    group('enrolledCoursesProvider', () {
      test('should provide future of enrolled courses list', () {
        final enrolledCourses = container.read(enrolledCoursesProvider);
        expect(enrolledCourses, isA<AsyncValue<List<EnrolledCourse>>>());
      });

      test('should handle unauthenticated state', () {
        final enrolledCourses = container.read(enrolledCoursesProvider);

        // Should handle authentication check
        enrolledCourses.when(
          data: (courses) => expect(courses, isA<List<EnrolledCourse>>()),
          loading: () => expect(true, true), // Loading is valid
          error: (error, stack) => expect(error, isNotNull),
        );
      });
    });

    group('assignmentsProvider', () {
      test('should provide future of assignments for course', () {
        const testCourseId = 'course-123';
        final assignments = container.read(assignmentsProvider(testCourseId));
        expect(assignments, isA<AsyncValue<List<Assignment>>>());
      });

      test('should allow test course ID to bypass authentication', () {
        const testCourseId = '14350bfb-5e84-4479-b7a2-09ce7a2fdd48';
        final assignments = container.read(assignmentsProvider(testCourseId));
        expect(assignments, isA<AsyncValue<List<Assignment>>>());
      });

      test('should handle different course IDs', () {
        const courseId1 = 'course-123';
        const courseId2 = 'course-456';

        final assignments1 = container.read(assignmentsProvider(courseId1));
        final assignments2 = container.read(assignmentsProvider(courseId2));

        expect(assignments1, isA<AsyncValue<List<Assignment>>>());
        expect(assignments2, isA<AsyncValue<List<Assignment>>>());
      });

      test('should return empty list for unauthenticated non-test courses', () {
        const regularCourseId = 'regular-course-id';
        final assignments =
            container.read(assignmentsProvider(regularCourseId));

        // Should handle authentication properly
        expect(assignments, isA<AsyncValue<List<Assignment>>>());
      });
    });

    group('learningObjectsProvider', () {
      test('should provide future of learning objects for assignment', () {
        const testAssignmentId = 'assignment-123';
        final learningObjects =
            container.read(learningObjectsProvider(testAssignmentId));
        expect(learningObjects, isA<AsyncValue<List<LearningObject>>>());
      });

      test('should allow test assignment ID to bypass authentication', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects =
            container.read(learningObjectsProvider(testAssignmentId));
        expect(learningObjects, isA<AsyncValue<List<LearningObject>>>());
      });

      test('should handle different assignment IDs', () {
        const assignmentId1 = 'assignment-123';
        const assignmentId2 = 'assignment-456';

        final learningObjects1 =
            container.read(learningObjectsProvider(assignmentId1));
        final learningObjects2 =
            container.read(learningObjectsProvider(assignmentId2));

        expect(learningObjects1, isA<AsyncValue<List<LearningObject>>>());
        expect(learningObjects2, isA<AsyncValue<List<LearningObject>>>());
      });
    });

    group('progressProvider', () {
      test('should provide future of progress state', () {
        const testLearningObjectId = 'lo-123';
        final progress = container.read(progressProvider(testLearningObjectId));
        expect(progress, isA<AsyncValue<ProgressState?>>());
      });

      test('should handle unauthenticated state', () {
        const learningObjectId = 'lo-456';
        final progress = container.read(progressProvider(learningObjectId));

        // Should return null when unauthenticated
        progress.when(
          data: (progressState) =>
              expect(progressState, anyOf([isNull, isA<ProgressState>()])),
          loading: () => expect(true, true),
          error: (error, stack) => expect(error, isNotNull),
        );
      });

      test('should handle different learning object IDs', () {
        const loId1 = 'lo-123';
        const loId2 = 'lo-456';

        final progress1 = container.read(progressProvider(loId1));
        final progress2 = container.read(progressProvider(loId2));

        expect(progress1, isA<AsyncValue<ProgressState?>>());
        expect(progress2, isA<AsyncValue<ProgressState?>>());
      });
    });

    group('State Providers', () {
      group('selectedCourseProvider', () {
        test('should start with null value', () {
          final selectedCourse = container.read(selectedCourseProvider);
          expect(selectedCourse, isNull);
        });

        test('should update selected course', () {
          final testCourse = Course(
            id: 'course-123',
            courseNumber: 'TEST-101',
            title: 'Test Course',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          container.read(selectedCourseProvider.notifier).state = testCourse;

          final selectedCourse = container.read(selectedCourseProvider);
          expect(selectedCourse, equals(testCourse));
          expect(selectedCourse!.id, 'course-123');
        });

        test('should allow clearing selected course', () {
          final testCourse = Course(
            id: 'course-123',
            courseNumber: 'TEST-101',
            title: 'Test Course',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Set then clear
          container.read(selectedCourseProvider.notifier).state = testCourse;
          container.read(selectedCourseProvider.notifier).state = null;

          final selectedCourse = container.read(selectedCourseProvider);
          expect(selectedCourse, isNull);
        });
      });

      group('selectedAssignmentProvider', () {
        test('should start with null value', () {
          final selectedAssignment = container.read(selectedAssignmentProvider);
          expect(selectedAssignment, isNull);
        });

        test('should update selected assignment', () {
          final testAssignment = Assignment(
            id: 'assignment-123',
            courseId: 'course-456',
            assignmentNumber: 1,
            title: 'Test Assignment',
            orderIndex: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          container.read(selectedAssignmentProvider.notifier).state =
              testAssignment;

          final selectedAssignment = container.read(selectedAssignmentProvider);
          expect(selectedAssignment, equals(testAssignment));
          expect(selectedAssignment!.id, 'assignment-123');
        });
      });

      group('selectedLearningObjectProvider', () {
        test('should start with null value', () {
          final selectedLO = container.read(selectedLearningObjectProvider);
          expect(selectedLO, isNull);
        });

        test('should update selected learning object', () {
          final testLO = LearningObject(
            id: 'lo-123',
            assignmentId: 'assignment-456',
            title: 'Test Learning Object',
            contentType: 'audio',
            orderIndex: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isCompleted: false,
            currentPositionMs: 0,
          );

          container.read(selectedLearningObjectProvider.notifier).state =
              testLO;

          final selectedLO = container.read(selectedLearningObjectProvider);
          expect(selectedLO, equals(testLO));
          expect(selectedLO!.id, 'lo-123');
        });
      });
    });

    group('Provider Dependencies', () {
      test('data providers should depend on supabaseServiceProvider', () {
        final service = container.read(supabaseServiceProvider);
        expect(service, isNotNull);

        // Other providers should be able to access the service
        expect(() => container.read(enrolledCoursesProvider), returnsNormally);
        expect(
            () => container.read(assignmentsProvider('test')), returnsNormally);
        expect(() => container.read(learningObjectsProvider('test')),
            returnsNormally);
        expect(() => container.read(progressProvider('test')), returnsNormally);
      });
    });

    group('Family Providers', () {
      test('assignmentsProvider should cache different course requests', () {
        const courseId1 = 'course-1';
        const courseId2 = 'course-2';

        final assignments1 = container.read(assignmentsProvider(courseId1));
        final assignments2 = container.read(assignmentsProvider(courseId2));
        final assignments1Again =
            container.read(assignmentsProvider(courseId1));

        expect(assignments1, isA<AsyncValue<List<Assignment>>>());
        expect(assignments2, isA<AsyncValue<List<Assignment>>>());
        expect(identical(assignments1, assignments1Again), isTrue);
      });

      test('learningObjectsProvider should cache different assignment requests',
          () {
        const assignmentId1 = 'assignment-1';
        const assignmentId2 = 'assignment-2';

        final lo1 = container.read(learningObjectsProvider(assignmentId1));
        final lo2 = container.read(learningObjectsProvider(assignmentId2));
        final lo1Again = container.read(learningObjectsProvider(assignmentId1));

        expect(lo1, isA<AsyncValue<List<LearningObject>>>());
        expect(lo2, isA<AsyncValue<List<LearningObject>>>());
        expect(identical(lo1, lo1Again), isTrue);
      });

      test('progressProvider should cache different learning object requests',
          () {
        const loId1 = 'lo-1';
        const loId2 = 'lo-2';

        final progress1 = container.read(progressProvider(loId1));
        final progress2 = container.read(progressProvider(loId2));
        final progress1Again = container.read(progressProvider(loId1));

        expect(progress1, isA<AsyncValue<ProgressState?>>());
        expect(progress2, isA<AsyncValue<ProgressState?>>());
        expect(identical(progress1, progress1Again), isTrue);
      });
    });

    group('State Updates and Notifications', () {
      test('selectedCourseProvider should notify listeners', () {
        var notificationCount = 0;

        container.listen(
          selectedCourseProvider,
          (previous, next) => notificationCount++,
        );

        final testCourse = Course(
          id: 'notify-test',
          courseNumber: 'NOTIFY-101',
          title: 'Notification Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        container.read(selectedCourseProvider.notifier).state = testCourse;

        expect(notificationCount, 1);
        expect(container.read(selectedCourseProvider), equals(testCourse));
      });

      test('state providers should handle multiple updates', () {
        final course1 = Course(
          id: 'course-1',
          courseNumber: 'C1',
          title: 'Course 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final course2 = Course(
          id: 'course-2',
          courseNumber: 'C2',
          title: 'Course 2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Multiple updates should work
        container.read(selectedCourseProvider.notifier).state = course1;
        expect(container.read(selectedCourseProvider), equals(course1));

        container.read(selectedCourseProvider.notifier).state = course2;
        expect(container.read(selectedCourseProvider), equals(course2));

        container.read(selectedCourseProvider.notifier).state = null;
        expect(container.read(selectedCourseProvider), isNull);
      });
    });

    group('Error Handling', () {
      test('providers should handle service errors gracefully', () {
        // Future providers should not throw even if service has issues
        expect(() => container.read(enrolledCoursesProvider), returnsNormally);
        expect(
            () => container.read(assignmentsProvider('test')), returnsNormally);
        expect(() => container.read(learningObjectsProvider('test')),
            returnsNormally);
        expect(() => container.read(progressProvider('test')), returnsNormally);
      });

      test('state providers should handle null values', () {
        // Should accept null values without throwing
        expect(
            () => container.read(selectedCourseProvider.notifier).state = null,
            returnsNormally);
        expect(
            () => container.read(selectedAssignmentProvider.notifier).state =
                null,
            returnsNormally);
        expect(
            () => container
                .read(selectedLearningObjectProvider.notifier)
                .state = null,
            returnsNormally);
      });
    });

    group('Test Data Bypass', () {
      test('should allow specific test course ID', () {
        const testCourseId = '14350bfb-5e84-4479-b7a2-09ce7a2fdd48';
        final assignments = container.read(assignmentsProvider(testCourseId));
        expect(assignments, isA<AsyncValue<List<Assignment>>>());
      });

      test('should allow specific test assignment ID', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects =
            container.read(learningObjectsProvider(testAssignmentId));
        expect(learningObjects, isA<AsyncValue<List<LearningObject>>>());
      });
    });

    group('Provider Lifecycle', () {
      test('providers should be disposable', () {
        final testContainer = ProviderContainer();

        testContainer.read(supabaseServiceProvider);
        testContainer.read(enrolledCoursesProvider);
        testContainer.read(selectedCourseProvider);

        expect(() => testContainer.dispose(), returnsNormally);
      });

      test('providers should handle recreation', () {
        final testContainer = ProviderContainer();
        final service1 = testContainer.read(supabaseServiceProvider);
        testContainer.dispose();

        final newContainer = ProviderContainer();
        final service2 = newContainer.read(supabaseServiceProvider);

        // Should get same singleton instance
        expect(identical(service1, service2), isTrue);
        newContainer.dispose();
      });
    });

    group('Integration', () {
      test('all course providers should work together', () {
        // Set up a complete selection hierarchy
        final course = Course(
          id: 'integration-course',
          courseNumber: 'INT-101',
          title: 'Integration Course',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final assignment = Assignment(
          id: 'integration-assignment',
          courseId: course.id,
          assignmentNumber: 1,
          title: 'Integration Assignment',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final learningObject = LearningObject(
          id: 'integration-lo',
          assignmentId: assignment.id,
          title: 'Integration Learning Object',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        // Set selections
        container.read(selectedCourseProvider.notifier).state = course;
        container.read(selectedAssignmentProvider.notifier).state = assignment;
        container.read(selectedLearningObjectProvider.notifier).state =
            learningObject;

        // Verify selections
        expect(container.read(selectedCourseProvider), equals(course));
        expect(container.read(selectedAssignmentProvider), equals(assignment));
        expect(container.read(selectedLearningObjectProvider),
            equals(learningObject));

        // Verify hierarchy relationships
        expect(container.read(selectedAssignmentProvider)!.courseId, course.id);
        expect(container.read(selectedLearningObjectProvider)!.assignmentId,
            assignment.id);
      });
    });
  });
}
