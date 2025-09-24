import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/assignment.dart';

void main() {
  group('Assignment Model', () {
    final testJson = {
      'id': 'assign-789',
      'course_id': 'course-123',
      'assignment_number': 3,
      'title': 'Risk Management Fundamentals',
      'description': 'Understanding core risk management principles',
      'order_index': 2,
      'created_at': '2024-02-15T09:30:00Z',
    };

    group('Constructor', () {
      test('should create Assignment with all required fields', () {
        final now = DateTime.now();
        final assignment = Assignment(
          id: 'test-id',
          courseId: 'course-id',
          assignmentNumber: 1,
          title: 'Test Assignment',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        expect(assignment.id, 'test-id');
        expect(assignment.courseId, 'course-id');
        expect(assignment.assignmentNumber, 1);
        expect(assignment.title, 'Test Assignment');
        expect(assignment.description, isNull);
        expect(assignment.orderIndex, 0);
        expect(assignment.createdAt, isA<DateTime>());
      });

      test('should create Assignment with optional description', () {
        final now = DateTime.now();
        final assignment = Assignment(
          id: 'test-id',
          courseId: 'course-id',
          assignmentNumber: 2,
          title: 'Test Assignment',
          description: 'Detailed description',
          orderIndex: 1,
          createdAt: now,
          updatedAt: now,
        );

        expect(assignment.description, 'Detailed description');
      });
    });

    group('Display Properties', () {
      test('displayNumber should return string representation', () {
        final now = DateTime.now();
        final assignment = Assignment(
          id: 'test',
          courseId: 'course',
          assignmentNumber: 42,
          title: 'Test',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        expect(assignment.displayNumber, '42');
        expect(assignment.displayNumber, isA<String>());
      });
    });

    group('JSON Serialization', () {
      test('fromJson should parse valid JSON correctly', () {
        final assignment = Assignment.fromJson(testJson);

        expect(assignment.id, 'assign-789');
        expect(assignment.courseId, 'course-123');
        expect(assignment.assignmentNumber, 3);
        expect(assignment.title, 'Risk Management Fundamentals');
        expect(assignment.description,
            'Understanding core risk management principles');
        expect(assignment.orderIndex, 2);
        expect(assignment.createdAt, DateTime.parse('2024-02-15T09:30:00Z'));
      });

      test('fromJson should handle null description', () {
        final jsonWithoutDescription = {
          'id': 'assign-001',
          'course_id': 'course-001',
          'assignment_number': 1,
          'title': 'Assignment Without Description',
          'order_index': 0,
          'created_at': '2024-01-01T00:00:00Z',
        };

        final assignment = Assignment.fromJson(jsonWithoutDescription);
        expect(assignment.description, isNull);
      });

      test('toJson should serialize all fields correctly', () {
        final assignment = Assignment.fromJson(testJson);
        final json = assignment.toJson();

        expect(json['id'], 'assign-789');
        expect(json['course_id'], 'course-123');
        expect(json['assignment_number'], 3);
        expect(json['title'], 'Risk Management Fundamentals');
        expect(json['description'],
            'Understanding core risk management principles');
        expect(json['order_index'], 2);
        expect(json['created_at'], '2024-02-15T09:30:00.000Z');
      });

      test('round-trip serialization should preserve data', () {
        final original = Assignment.fromJson(testJson);
        final json = original.toJson();
        final restored = Assignment.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.courseId, original.courseId);
        expect(restored.assignmentNumber, original.assignmentNumber);
        expect(restored.title, original.title);
        expect(restored.description, original.description);
        expect(restored.orderIndex, original.orderIndex);
        expect(restored.createdAt, original.createdAt);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = Assignment.fromJson(testJson);
        final updated = original.copyWith(
          title: 'Updated Title',
          assignmentNumber: 5,
          description: 'New Description',
        );

        expect(updated.id, original.id);
        expect(updated.courseId, original.courseId);
        expect(updated.title, 'Updated Title');
        expect(updated.assignmentNumber, 5);
        expect(updated.description, 'New Description');
        expect(updated.orderIndex, original.orderIndex);
        expect(updated.createdAt, original.createdAt);
      });

      test('should preserve original when no fields changed', () {
        final original = Assignment.fromJson(testJson);
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.courseId, original.courseId);
        expect(copy.assignmentNumber, original.assignmentNumber);
        expect(copy.title, original.title);
        expect(copy.description, original.description);
        expect(copy.orderIndex, original.orderIndex);
        expect(copy.createdAt, original.createdAt);
      });

      test('should allow clearing nullable fields', () {
        final now = DateTime.now();
        final original = Assignment(
          id: 'test',
          courseId: 'course',
          assignmentNumber: 1,
          title: 'Test',
          description: 'Has description',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        final updated = original.copyWith(description: null);
        expect(updated.description, isNull);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final now = DateTime.now();
        final assignment1 = Assignment(
          id: 'same-id',
          courseId: 'course-1',
          assignmentNumber: 1,
          title: 'Assignment 1',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        final assignment2 = Assignment(
          id: 'same-id',
          courseId: 'course-2',
          assignmentNumber: 2,
          title: 'Assignment 2',
          orderIndex: 1,
          createdAt: now.add(const Duration(days: 1)),
          updatedAt: now.add(const Duration(days: 1)),
        );

        expect(assignment1, equals(assignment2));
        expect(assignment1.hashCode, assignment2.hashCode);
      });

      test('should not be equal when IDs differ', () {
        final now = DateTime.now();
        final assignment1 = Assignment(
          id: 'id-1',
          courseId: 'same-course',
          assignmentNumber: 1,
          title: 'Same Title',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        final assignment2 = Assignment(
          id: 'id-2',
          courseId: 'same-course',
          assignmentNumber: 1,
          title: 'Same Title',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        expect(assignment1, isNot(equals(assignment2)));
        expect(assignment1.hashCode, isNot(assignment2.hashCode));
      });

      test('should be equal to itself', () {
        final assignment = Assignment.fromJson(testJson);
        expect(assignment, equals(assignment));
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final now = DateTime.now();
        final assignment = Assignment(
          id: 'test-123',
          courseId: 'course-456',
          assignmentNumber: 7,
          title: 'Advanced Topics',
          orderIndex: 6,
          createdAt: now,
          updatedAt: now,
        );

        final str = assignment.toString();
        expect(str, contains('test-123'));
        expect(str, contains('7'));
        expect(str, contains('Advanced Topics'));
      });
    });

    group('Ordering', () {
      test('should maintain order index', () {
        final assignments = [
          Assignment(
            id: 'a1',
            courseId: 'c1',
            assignmentNumber: 1,
            title: 'First',
            orderIndex: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Assignment(
            id: 'a2',
            courseId: 'c1',
            assignmentNumber: 2,
            title: 'Second',
            orderIndex: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Assignment(
            id: 'a3',
            courseId: 'c1',
            assignmentNumber: 3,
            title: 'Third',
            orderIndex: 2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Sort by orderIndex
        assignments.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

        expect(assignments[0].title, 'First');
        expect(assignments[1].title, 'Second');
        expect(assignments[2].title, 'Third');
      });

      test('assignment number and order index can differ', () {
        final now = DateTime.now();
        final assignment = Assignment(
          id: 'test',
          courseId: 'course',
          assignmentNumber: 5, // Display number
          title: 'Test',
          orderIndex: 0, // First in order despite being #5
          createdAt: now,
          updatedAt: now,
        );

        expect(assignment.assignmentNumber, 5);
        expect(assignment.orderIndex, 0);
        expect(assignment.displayNumber, '5');
      });
    });

    group('Validation Function', () {
      test('validateAssignmentModel should not throw', () {
        expect(() => validateAssignmentModel(), returnsNormally);
      });
    });

    group('Course Relationship', () {
      test('should maintain course ID reference', () {
        final now = DateTime.now();
        final assignment = Assignment(
          id: 'assign-1',
          courseId: 'course-xyz',
          assignmentNumber: 1,
          title: 'Test',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        expect(assignment.courseId, 'course-xyz');
      });

      test('multiple assignments can belong to same course', () {
        final courseId = 'shared-course-id';
        final now = DateTime.now();
        final assignment1 = Assignment(
          id: 'a1',
          courseId: courseId,
          assignmentNumber: 1,
          title: 'First',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        );

        final assignment2 = Assignment(
          id: 'a2',
          courseId: courseId,
          assignmentNumber: 2,
          title: 'Second',
          orderIndex: 1,
          createdAt: now,
          updatedAt: now,
        );

        expect(assignment1.courseId, assignment2.courseId);
      });
    });
  });
}
