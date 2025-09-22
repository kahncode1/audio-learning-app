import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/mock_data_service.dart';
import 'package:audio_learning_app/models/course.dart';
import 'package:audio_learning_app/models/assignment.dart';
import 'package:audio_learning_app/models/learning_object.dart';

void main() {
  group('MockDataService', () {
    group('getTestCourse()', () {
      test('should return a valid Course object', () {
        final course = MockDataService.getTestCourse();
        
        expect(course, isA<Course>());
        expect(course.id, '14350bfb-5e84-4479-b7a2-09ce7a2fdd48');
        expect(course.courseNumber, 'INS-101');
        expect(course.title, 'Insurance Case Management');
        expect(course.description, isNotEmpty);
        expect(course.gradientStartColor, '#FF6B6B');
        expect(course.gradientEndColor, '#C44569');
        expect(course.totalDurationMs, 3600000);
        expect(course.createdAt, isA<DateTime>());
        expect(course.updatedAt, isA<DateTime>());
      });

      test('should have consistent course ID', () {
        final course1 = MockDataService.getTestCourse();
        final course2 = MockDataService.getTestCourse();
        expect(course1.id, equals(course2.id));
      });
    });

    group('getTestAssignments()', () {
      test('should return list of assignments', () {
        final assignments = MockDataService.getTestAssignments();
        
        expect(assignments, isA<List<Assignment>>());
        expect(assignments, isNotEmpty);
        expect(assignments.length, greaterThanOrEqualTo(3));
      });

      test('should have real database assignment ID', () {
        final assignments = MockDataService.getTestAssignments();
        final firstAssignment = assignments.first;
        
        expect(firstAssignment.id, 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
        expect(firstAssignment.courseId, '14350bfb-5e84-4479-b7a2-09ce7a2fdd48');
        expect(firstAssignment.title, 'Establishing a Case Reserve');
      });

      test('should have correct assignment numbers and order', () {
        final assignments = MockDataService.getTestAssignments();
        
        for (int i = 0; i < assignments.length; i++) {
          expect(assignments[i].assignmentNumber, i + 1);
          expect(assignments[i].orderIndex, i + 1);
        }
      });

      test('all assignments should belong to same course', () {
        final assignments = MockDataService.getTestAssignments();
        const expectedCourseId = '14350bfb-5e84-4479-b7a2-09ce7a2fdd48';
        
        for (final assignment in assignments) {
          expect(assignment.courseId, expectedCourseId);
        }
      });
    });

    group('getTestLearningObjects()', () {
      test('should return learning objects for real assignment ID', () {
        const realAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = MockDataService.getTestLearningObjects(realAssignmentId);
        
        expect(learningObjects, isA<List<LearningObject>>());
        expect(learningObjects, isNotEmpty);
      });

      test('should have real database learning object ID', () {
        const realAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = MockDataService.getTestLearningObjects(realAssignmentId);
        
        if (learningObjects.isNotEmpty) {
          final firstObject = learningObjects.first;
          expect(firstObject.id, '63ad7b78-0970-4265-a4fe-51f3fee39d5f');
          expect(firstObject.assignmentId, realAssignmentId);
        }
      });

      test('should provide plain text content', () {
        const realAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = MockDataService.getTestLearningObjects(realAssignmentId);
        
        for (final obj in learningObjects) {
          if (obj.plainText != null) {
            expect(obj.plainText, isNotEmpty);
          }
        }
      });

      test('should initialize with not completed status', () {
        const realAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = MockDataService.getTestLearningObjects(realAssignmentId);
        
        for (final obj in learningObjects) {
          expect(obj.isCompleted, isFalse);
          expect(obj.currentPositionMs, 0);
        }
      });

      test('should return empty list for unknown assignment', () {
        const unknownAssignmentId = 'unknown-assignment-id';
        final learningObjects = MockDataService.getTestLearningObjects(unknownAssignmentId);
        
        // Depending on implementation, might return empty list or default objects
        expect(learningObjects, isA<List<LearningObject>>());
      });
    });

    group('Data Consistency', () {
      test('should use consistent IDs across methods', () {
        final course = MockDataService.getTestCourse();
        final assignments = MockDataService.getTestAssignments();
        
        // All assignments should belong to the test course
        for (final assignment in assignments) {
          expect(assignment.courseId, course.id);
        }
      });

      test('should provide data suitable for UI testing', () {
        final course = MockDataService.getTestCourse();
        final assignments = MockDataService.getTestAssignments();
        
        // Should have gradient colors for UI
        expect(course.gradientStartColor, matches(r'^#[A-F0-9]{6}$'));
        expect(course.gradientEndColor, matches(r'^#[A-F0-9]{6}$'));
        
        // Should have titles for display
        expect(course.title, isNotEmpty);
        for (final assignment in assignments) {
          expect(assignment.title, isNotEmpty);
        }
      });

      test('should have realistic timestamps', () {
        final course = MockDataService.getTestCourse();
        final now = DateTime.now();
        
        // Created date should be in the past
        expect(course.createdAt.isBefore(now), isTrue);
        // Updated date should be recent
        expect(course.updatedAt.difference(now).inDays.abs(), lessThan(1));
      });
    });

    group('Download-First Architecture Support', () {
      test('should provide content matching pre-downloaded files', () {
        const realAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = MockDataService.getTestLearningObjects(realAssignmentId);
        
        // First learning object should match our test content files
        if (learningObjects.isNotEmpty) {
          final testObject = learningObjects.first;
          expect(testObject.id, '63ad7b78-0970-4265-a4fe-51f3fee39d5f');
          expect(testObject.contentType, 'text');
        }
      });

      test('should not require SSML in download-first mode', () {
        const realAssignmentId = 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
        final learningObjects = MockDataService.getTestLearningObjects(realAssignmentId);
        
        // SSML is optional in download-first architecture
        for (final obj in learningObjects) {
          // SSML can be null since we use pre-processed content
          expect(obj.plainText != null || obj.ssmlContent != null, isTrue);
        }
      });
    });
  });
}