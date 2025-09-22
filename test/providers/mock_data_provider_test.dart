import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_learning_app/providers/mock_data_provider.dart';
import 'package:audio_learning_app/models/course.dart';
import 'package:audio_learning_app/models/assignment.dart';
import 'package:audio_learning_app/models/learning_object.dart';
import 'package:audio_learning_app/services/mock_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mock Data Provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('mockCourseProvider', () {
      test('should provide test course', () {
        final course = container.read(mockCourseProvider);
        
        expect(course, isA<Course>());
        expect(course.id, 'test-course-001');
        expect(course.title, 'Insurance Case Management');
        expect(course.courseNumber, 'INS-101');
      });

      test('should return same instance on multiple reads', () {
        final course1 = container.read(mockCourseProvider);
        final course2 = container.read(mockCourseProvider);
        
        expect(identical(course1, course2), isTrue);
        expect(course1.id, course2.id);
      });

      test('should provide course with gradient', () {
        final course = container.read(mockCourseProvider);
        
        expect(course.gradientStart, isNotNull);
        expect(course.gradientEnd, isNotNull);
        expect(course.gradientStart, isNot(course.gradientEnd));
      });

      test('should provide course with valid timestamps', () {
        final course = container.read(mockCourseProvider);
        
        expect(course.createdAt, isA<DateTime>());
        expect(course.updatedAt, isA<DateTime>());
        expect(course.createdAt.isBefore(DateTime.now().add(Duration(seconds: 1))), isTrue);
      });
    });

    group('mockAssignmentsProvider', () {
      test('should provide list of test assignments', () {
        final assignments = container.read(mockAssignmentsProvider);
        
        expect(assignments, isA<List<Assignment>>());
        expect(assignments.length, 3);
      });

      test('should provide assignments with correct structure', () {
        final assignments = container.read(mockAssignmentsProvider);
        
        for (int i = 0; i < assignments.length; i++) {
          final assignment = assignments[i];
          expect(assignment.id, isNotEmpty);
          expect(assignment.courseId, 'test-course-001');
          expect(assignment.title, isNotEmpty);
          expect(assignment.assignmentNumber, i + 1);
          expect(assignment.orderIndex, i);
        }
      });

      test('should return same instance on multiple reads', () {
        final assignments1 = container.read(mockAssignmentsProvider);
        final assignments2 = container.read(mockAssignmentsProvider);
        
        expect(identical(assignments1, assignments2), isTrue);
        expect(assignments1.length, assignments2.length);
      });

      test('should provide assignments with valid timestamps', () {
        final assignments = container.read(mockAssignmentsProvider);
        
        for (final assignment in assignments) {
          expect(assignment.createdAt, isA<DateTime>());
          expect(assignment.createdAt.isBefore(DateTime.now().add(Duration(seconds: 1))), isTrue);
        }
      });

      test('should have specific test assignment ID', () {
        final assignments = container.read(mockAssignmentsProvider);
        
        // First assignment should have the test ID used in course providers
        expect(assignments.first.id, 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      });
    });

    group('mockLearningObjectsProvider', () {
      test('should provide learning objects for valid assignment', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = container.read(mockLearningObjectsProvider(testAssignmentId));
        
        expect(learningObjects, isA<List<LearningObject>>());
        expect(learningObjects.length, 2);
      });

      test('should return empty list for non-existent assignment', () {
        const invalidAssignmentId = 'invalid-assignment-id';
        final learningObjects = container.read(mockLearningObjectsProvider(invalidAssignmentId));
        
        expect(learningObjects, isA<List<LearningObject>>());
        expect(learningObjects.isEmpty, isTrue);
      });

      test('should provide learning objects with correct structure', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = container.read(mockLearningObjectsProvider(testAssignmentId));
        
        for (int i = 0; i < learningObjects.length; i++) {
          final lo = learningObjects[i];
          expect(lo.id, isNotEmpty);
          expect(lo.assignmentId, testAssignmentId);
          expect(lo.title, isNotEmpty);
          expect(lo.contentType, 'audio');
          expect(lo.orderIndex, i);
          expect(lo.isCompleted, isFalse);
          expect(lo.currentPositionMs, 0);
        }
      });

      test('should cache different assignment requests', () {
        const assignmentId1 = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        const assignmentId2 = 'test-assignment-002';
        
        final lo1 = container.read(mockLearningObjectsProvider(assignmentId1));
        final lo2 = container.read(mockLearningObjectsProvider(assignmentId2));
        final lo1Again = container.read(mockLearningObjectsProvider(assignmentId1));
        
        expect(identical(lo1, lo1Again), isTrue);
        expect(lo1.length, 2);
        expect(lo2.length, 0);
      });

      test('should provide learning objects with valid timestamps', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = container.read(mockLearningObjectsProvider(testAssignmentId));
        
        for (final lo in learningObjects) {
          expect(lo.createdAt, isA<DateTime>());
          expect(lo.updatedAt, isA<DateTime>());
          expect(lo.createdAt.isBefore(DateTime.now().add(Duration(seconds: 1))), isTrue);
        }
      });
    });

    group('mockCourseCompletionProvider', () {
      test('should provide completion percentage', () {
        final completion = container.read(mockCourseCompletionProvider);
        
        expect(completion, isA<double>());
        expect(completion, 25.0);
      });

      test('should return valid percentage range', () {
        final completion = container.read(mockCourseCompletionProvider);
        
        expect(completion, greaterThanOrEqualTo(0.0));
        expect(completion, lessThanOrEqualTo(100.0));
      });

      test('should return same value on multiple reads', () {
        final completion1 = container.read(mockCourseCompletionProvider);
        final completion2 = container.read(mockCourseCompletionProvider);
        
        expect(completion1, completion2);
      });
    });

    group('mockAssignmentCountProvider', () {
      test('should provide assignment count', () {
        final count = container.read(mockAssignmentCountProvider);
        
        expect(count, isA<int>());
        expect(count, 3);
      });

      test('should match actual assignments list length', () {
        final count = container.read(mockAssignmentCountProvider);
        final assignments = container.read(mockAssignmentsProvider);
        
        expect(count, assignments.length);
      });

      test('should return positive count', () {
        final count = container.read(mockAssignmentCountProvider);
        
        expect(count, greaterThan(0));
      });
    });

    group('mockLearningObjectCountProvider', () {
      test('should provide learning object count', () {
        final count = container.read(mockLearningObjectCountProvider);
        
        expect(count, isA<int>());
        expect(count, 2);
      });

      test('should return non-negative count', () {
        final count = container.read(mockLearningObjectCountProvider);
        
        expect(count, greaterThanOrEqualTo(0));
      });

      test('should match actual learning objects count', () {
        final count = container.read(mockLearningObjectCountProvider);
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = container.read(mockLearningObjectsProvider(testAssignmentId));
        
        expect(count, learningObjects.length);
      });
    });

    group('Provider Integration', () {
      test('all providers should work together consistently', () {
        final course = container.read(mockCourseProvider);
        final assignments = container.read(mockAssignmentsProvider);
        final assignmentCount = container.read(mockAssignmentCountProvider);
        final completion = container.read(mockCourseCompletionProvider);
        
        expect(course.id, 'test-course-001');
        expect(assignments.length, assignmentCount);
        expect(assignments.first.courseId, course.id);
        expect(completion, isA<double>());
      });

      test('should provide consistent learning object data', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = container.read(mockLearningObjectsProvider(testAssignmentId));
        final loCount = container.read(mockLearningObjectCountProvider);
        
        expect(learningObjects.length, loCount);
        for (final lo in learningObjects) {
          expect(lo.assignmentId, testAssignmentId);
        }
      });

      test('should maintain referential integrity', () {
        final course = container.read(mockCourseProvider);
        final assignments = container.read(mockAssignmentsProvider);
        
        // All assignments should reference the same course
        for (final assignment in assignments) {
          expect(assignment.courseId, course.id);
        }
      });
    });

    group('Family Provider Behavior', () {
      test('should handle different assignment IDs independently', () {
        const assignmentId1 = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        const assignmentId2 = 'test-assignment-002';
        const assignmentId3 = 'test-assignment-003';
        
        final lo1 = container.read(mockLearningObjectsProvider(assignmentId1));
        final lo2 = container.read(mockLearningObjectsProvider(assignmentId2));
        final lo3 = container.read(mockLearningObjectsProvider(assignmentId3));
        
        expect(lo1.length, 2);
        expect(lo2.length, 0);
        expect(lo3.length, 0);
      });

      test('should cache family provider results', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        
        final lo1 = container.read(mockLearningObjectsProvider(testAssignmentId));
        final lo2 = container.read(mockLearningObjectsProvider(testAssignmentId));
        
        expect(identical(lo1, lo2), isTrue);
      });
    });

    group('Data Consistency', () {
      test('should provide consistent data across multiple reads', () {
        // Read all providers multiple times
        for (int i = 0; i < 5; i++) {
          final course = container.read(mockCourseProvider);
          final assignments = container.read(mockAssignmentsProvider);
          final completion = container.read(mockCourseCompletionProvider);
          
          expect(course.id, 'test-course-001');
          expect(assignments.length, 3);
          expect(completion, 25.0);
        }
      });

      test('should maintain data structure integrity', () {
        final course = container.read(mockCourseProvider);
        final assignments = container.read(mockAssignmentsProvider);
        
        // Verify course structure
        expect(course.id, isNotEmpty);
        expect(course.title, isNotEmpty);
        expect(course.courseNumber, isNotEmpty);
        
        // Verify assignment structure
        for (final assignment in assignments) {
          expect(assignment.id, isNotEmpty);
          expect(assignment.courseId, course.id);
          expect(assignment.title, isNotEmpty);
          expect(assignment.assignmentNumber, greaterThan(0));
          expect(assignment.orderIndex, greaterThanOrEqualTo(0));
        }
      });
    });

    group('Provider Lifecycle', () {
      test('providers should be disposable', () {
        final testContainer = ProviderContainer();
        
        testContainer.read(mockCourseProvider);
        testContainer.read(mockAssignmentsProvider);
        testContainer.read(mockCourseCompletionProvider);
        
        expect(() => testContainer.dispose(), returnsNormally);
      });

      test('should handle provider recreation', () {
        final testContainer = ProviderContainer();
        final course1 = testContainer.read(mockCourseProvider);
        testContainer.dispose();
        
        final newContainer = ProviderContainer();
        final course2 = newContainer.read(mockCourseProvider);
        
        // Should provide same data but different instances
        expect(course1.id, course2.id);
        expect(course1.title, course2.title);
        newContainer.dispose();
      });
    });

    group('MockDataService Integration', () {
      test('should delegate to MockDataService correctly', () {
        final course = container.read(mockCourseProvider);
        final directCourse = MockDataService.getTestCourse();
        
        expect(course.id, directCourse.id);
        expect(course.title, directCourse.title);
      });

      test('should handle service method calls', () {
        final assignments = container.read(mockAssignmentsProvider);
        final directAssignments = MockDataService.getTestAssignments();
        
        expect(assignments.length, directAssignments.length);
      });

      test('should maintain service data consistency', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = container.read(mockLearningObjectsProvider(testAssignmentId));
        final directLearningObjects = MockDataService.getTestLearningObjects(testAssignmentId);
        
        expect(learningObjects.length, directLearningObjects.length);
      });
    });

    group('Error Handling', () {
      test('should handle invalid assignment IDs gracefully', () {
        const invalidId = 'completely-invalid-id';
        final learningObjects = container.read(mockLearningObjectsProvider(invalidId));
        
        expect(learningObjects, isA<List<LearningObject>>());
        expect(learningObjects.isEmpty, isTrue);
      });

      test('should provide stable data despite edge cases', () {
        // Test with various edge case inputs
        final emptyId = container.read(mockLearningObjectsProvider(''));
        final nullLikeId = container.read(mockLearningObjectsProvider('null'));
        final specialChars = container.read(mockLearningObjectsProvider('test-@#\$%'));
        
        expect(emptyId, isA<List<LearningObject>>());
        expect(nullLikeId, isA<List<LearningObject>>());
        expect(specialChars, isA<List<LearningObject>>());
      });
    });

    group('Performance', () {
      test('should handle multiple provider reads efficiently', () {
        // Read providers many times to test performance
        for (int i = 0; i < 100; i++) {
          container.read(mockCourseProvider);
          container.read(mockAssignmentsProvider);
          container.read(mockCourseCompletionProvider);
        }
        
        // Should complete without timeout
        expect(container.read(mockCourseProvider), isA<Course>());
      });

      test('should cache family provider results efficiently', () {
        const testAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        
        // Read the same family provider many times
        for (int i = 0; i < 100; i++) {
          final lo = container.read(mockLearningObjectsProvider(testAssignmentId));
          expect(lo.length, 2);
        }
      });
    });
  });
}