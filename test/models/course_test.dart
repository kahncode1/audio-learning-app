import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:audio_learning_app/models/course.dart';

void main() {
  group('Course Model', () {
    final testJson = {
      'id': 'test-course-123',
      'course_number': 'CS-101',
      'title': 'Introduction to Computer Science',
      'description': 'A comprehensive introduction to CS concepts',
      'gradient_start_color': '#4CAF50',
      'gradient_end_color': '#2E7D32',
      'total_duration_ms': 7200000,
      'created_at': '2024-01-15T10:30:00Z',
      'updated_at': '2024-01-20T14:45:00Z',
    };

    group('Constructor', () {
      test('should create Course with all required fields', () {
        final course = Course(
          id: 'test-id',
          courseNumber: 'TEST-101',
          title: 'Test Course',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(course.id, 'test-id');
        expect(course.courseNumber, 'TEST-101');
        expect(course.title, 'Test Course');
        expect(course.description, isNull);
        expect(course.gradientStartColor, '#2196F3'); // Default
        expect(course.gradientEndColor, '#1976D2'); // Default
        expect(course.estimatedDurationMs, 0); // Default
      });

      test('should create Course with optional fields', () {
        final now = DateTime.now();
        final course = Course(
          id: 'test-id',
          courseNumber: 'TEST-101',
          title: 'Test Course',
          description: 'Test Description',
          gradientStartColor: '#FF0000',
          gradientEndColor: '#00FF00',
          estimatedDurationMs: 1800000,
          createdAt: now,
          updatedAt: now,
        );

        expect(course.description, 'Test Description');
        expect(course.gradientStartColor, '#FF0000');
        expect(course.gradientEndColor, '#00FF00');
        expect(course.estimatedDurationMs, 1800000);
      });
    });

    group('JSON Serialization', () {
      test('fromJson should parse valid JSON correctly', () {
        final course = Course.fromJson(testJson);

        expect(course.id, 'test-course-123');
        expect(course.courseNumber, 'CS-101');
        expect(course.title, 'Introduction to Computer Science');
        expect(
            course.description, 'A comprehensive introduction to CS concepts');
        expect(course.gradientStartColor, '#4CAF50');
        expect(course.gradientEndColor, '#2E7D32');
        expect(course.estimatedDurationMs, 7200000);
        expect(course.createdAt, DateTime.parse('2024-01-15T10:30:00Z'));
        expect(course.updatedAt, DateTime.parse('2024-01-20T14:45:00Z'));
      });

      test('fromJson should use defaults for missing optional fields', () {
        final minimalJson = {
          'id': 'minimal-id',
          'course_number': 'MIN-101',
          'title': 'Minimal Course',
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        final course = Course.fromJson(minimalJson);

        expect(course.description, isNull);
        expect(course.gradientStartColor, '#2196F3');
        expect(course.gradientEndColor, '#1976D2');
        expect(course.estimatedDurationMs, 0);
      });

      test('toJson should serialize all fields correctly', () {
        final course = Course.fromJson(testJson);
        final json = course.toJson();

        expect(json['id'], 'test-course-123');
        expect(json['course_number'], 'CS-101');
        expect(json['title'], 'Introduction to Computer Science');
        expect(
            json['description'], 'A comprehensive introduction to CS concepts');
        expect(json['gradient_start_color'], '#4CAF50');
        expect(json['gradient_end_color'], '#2E7D32');
        expect(json['total_duration_ms'], 7200000);
        expect(json['created_at'], '2024-01-15T10:30:00.000Z');
        expect(json['updated_at'], '2024-01-20T14:45:00.000Z');
      });

      test('round-trip serialization should preserve data', () {
        final original = Course.fromJson(testJson);
        final json = original.toJson();
        final restored = Course.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.courseNumber, original.courseNumber);
        expect(restored.title, original.title);
        expect(restored.description, original.description);
        expect(restored.gradientStartColor, original.gradientStartColor);
        expect(restored.gradientEndColor, original.gradientEndColor);
        expect(restored.estimatedDurationMs, original.estimatedDurationMs);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });
    });

    group('Gradient Generation', () {
      test('should create LinearGradient from color strings', () {
        final course = Course.fromJson(testJson);
        final gradient = course.gradient;

        expect(gradient, isA<LinearGradient>());
        expect(gradient.colors.length, 2);
        expect(gradient.begin, Alignment.topLeft);
        expect(gradient.end, Alignment.bottomRight);
      });

      test('should handle hex colors with # prefix', () {
        final course = Course(
          id: 'test',
          courseNumber: 'TEST',
          title: 'Test',
          gradientStartColor: '#FF5722',
          gradientEndColor: '#E64A19',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final gradient = course.gradient;
        expect(gradient.colors[0], const Color(0xFFFF5722));
        expect(gradient.colors[1], const Color(0xFFE64A19));
      });

      test('should handle hex colors without # prefix', () {
        final course = Course(
          id: 'test',
          courseNumber: 'TEST',
          title: 'Test',
          gradientStartColor: 'FF5722',
          gradientEndColor: 'E64A19',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final gradient = course.gradient;
        expect(gradient.colors[0], const Color(0xFFFF5722));
        expect(gradient.colors[1], const Color(0xFFE64A19));
      });

      test('should use fallback color for invalid hex', () {
        final course = Course(
          id: 'test',
          courseNumber: 'TEST',
          title: 'Test',
          gradientStartColor: 'INVALID',
          gradientEndColor: 'XYZ',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final gradient = course.gradient;
        expect(gradient.colors[0], Colors.blue); // Fallback
        expect(gradient.colors[1], Colors.blue); // Fallback
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = Course.fromJson(testJson);
        final updated = original.copyWith(
          title: 'Updated Title',
          description: 'Updated Description',
        );

        expect(updated.id, original.id);
        expect(updated.courseNumber, original.courseNumber);
        expect(updated.title, 'Updated Title');
        expect(updated.description, 'Updated Description');
        expect(updated.gradientStartColor, original.gradientStartColor);
        expect(updated.createdAt, original.createdAt);
      });

      test('should preserve original when no fields changed', () {
        final original = Course.fromJson(testJson);
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.title, original.title);
        expect(copy.description, original.description);
        expect(copy.estimatedDurationMs, original.estimatedDurationMs);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final course1 = Course(
          id: 'same-id',
          courseNumber: 'C1',
          title: 'Course 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final course2 = Course(
          id: 'same-id',
          courseNumber: 'C2',
          title: 'Course 2',
          createdAt: DateTime.now().add(const Duration(days: 1)),
          updatedAt: DateTime.now().add(const Duration(days: 1)),
        );

        expect(course1, equals(course2));
        expect(course1.hashCode, course2.hashCode);
      });

      test('should not be equal when IDs differ', () {
        final course1 = Course(
          id: 'id-1',
          courseNumber: 'SAME',
          title: 'Same Title',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final course2 = Course(
          id: 'id-2',
          courseNumber: 'SAME',
          title: 'Same Title',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(course1, isNot(equals(course2)));
      });

      test('should be equal to itself', () {
        final course = Course.fromJson(testJson);
        expect(course, equals(course));
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final course = Course(
          id: 'test-123',
          courseNumber: 'CS-101',
          title: 'Computer Science',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final str = course.toString();
        expect(str, contains('test-123'));
        expect(str, contains('CS-101'));
        expect(str, contains('Computer Science'));
      });
    });

    group('Validation Function', () {
      test('validateCourseModel should not throw', () {
        expect(() => validateCourseModel(), returnsNormally);
      });
    });

    group('Duration Formatting', () {
      test('should handle duration in milliseconds', () {
        final course = Course(
          id: 'test',
          courseNumber: 'TEST',
          title: 'Test',
          estimatedDurationMs: 3600000, // 1 hour
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(course.estimatedDurationMs, 3600000);
        // Could add a getter for formatted duration
        final hours = course.estimatedDurationMs ~/ (1000 * 60 * 60);
        expect(hours, 1);
      });

      test('should handle zero duration', () {
        final course = Course(
          id: 'test',
          courseNumber: 'TEST',
          title: 'Test',
          estimatedDurationMs: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(course.estimatedDurationMs, 0);
      });
    });
  });
}
