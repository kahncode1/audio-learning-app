import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/enrolled_course.dart';
import 'package:audio_learning_app/models/course.dart';

void main() {
  group('EnrolledCourse Model', () {
    final futureDate = DateTime.now().add(const Duration(days: 30));
    final pastDate = DateTime.now().subtract(const Duration(days: 5));

    final testJson = {
      'id': 'enrollment-xyz123',
      'user_id': 'user-abc456',
      'course_id': 'course-def789',
      'enrolled_at': '2024-01-15T09:00:00Z',
      'expires_at': futureDate.toIso8601String(),
      'is_active': true,
      'completion_percentage': 45.8,
    };

    group('Constructor', () {
      test('should create EnrolledCourse with all required fields', () {
        final enrollment = EnrolledCourse(
          id: 'test-id',
          userId: 'user-id',
          courseId: 'course-id',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
        );

        expect(enrollment.id, 'test-id');
        expect(enrollment.userId, 'user-id');
        expect(enrollment.courseId, 'course-id');
        expect(enrollment.isActive, true); // Default
        expect(enrollment.completionPercentage, 0.0); // Default
        expect(enrollment.course, isNull);
      });

      test('should create EnrolledCourse with optional fields', () {
        final testCourse = Course(
          id: 'course-123',
          courseNumber: 'TEST-101',
          title: 'Test Course',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final enrollment = EnrolledCourse(
          id: 'test-id',
          userId: 'user-id',
          courseId: 'course-id',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          isActive: false,
          completionPercentage: 75.0,
          course: testCourse,
        );

        expect(enrollment.isActive, false);
        expect(enrollment.completionPercentage, 75.0);
        expect(enrollment.course, equals(testCourse));
      });
    });

    group('Expiration Logic', () {
      test('isExpired should return false for future dates', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
        );

        expect(enrollment.isExpired, false);
      });

      test('isExpired should return true for past dates', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: pastDate,
        );

        expect(enrollment.isExpired, true);
      });

      test('isValid should consider both active status and expiration', () {
        // Active and not expired
        final validEnrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          isActive: true,
        );
        expect(validEnrollment.isValid, true);

        // Inactive but not expired
        final inactiveEnrollment = validEnrollment.copyWith(isActive: false);
        expect(inactiveEnrollment.isValid, false);

        // Active but expired
        final expiredEnrollment = validEnrollment.copyWith(expiresAt: pastDate);
        expect(expiredEnrollment.isValid, false);

        // Inactive and expired
        final bothInvalid = validEnrollment.copyWith(
          isActive: false,
          expiresAt: pastDate,
        );
        expect(bothInvalid.isValid, false);
      });

      test('daysRemaining should calculate correctly', () {
        final in30Days = DateTime.now().add(const Duration(days: 30));
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: in30Days,
        );

        expect(enrollment.daysRemaining, closeTo(30, 1));
      });

      test('daysRemaining should return 0 for expired courses', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: pastDate,
        );

        expect(enrollment.daysRemaining, 0);
      });
    });

    group('Formatted Properties', () {
      test('formattedExpirationDate should format correctly', () {
        final specificDate = DateTime(2024, 12, 25);
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: specificDate,
        );

        expect(enrollment.formattedExpirationDate, '12/25/2024');
      });
    });

    group('Completion Status', () {
      test('should return "Not Started" for 0% completion', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          completionPercentage: 0.0,
        );

        expect(enrollment.completionStatus, 'Not Started');
      });

      test('should return "In Progress" for partial completion', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          completionPercentage: 50.0,
        );

        expect(enrollment.completionStatus, 'In Progress');
      });

      test('should return "Completed" for 100% completion', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          completionPercentage: 100.0,
        );

        expect(enrollment.completionStatus, 'Completed');
      });

      test('should return "Completed" for over 100% completion', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          completionPercentage: 105.0,
        );

        expect(enrollment.completionStatus, 'Completed');
      });
    });

    group('JSON Serialization', () {
      test('fromJson should parse valid JSON correctly', () {
        final enrollment = EnrolledCourse.fromJson(testJson);

        expect(enrollment.id, 'enrollment-xyz123');
        expect(enrollment.userId, 'user-abc456');
        expect(enrollment.courseId, 'course-def789');
        expect(enrollment.enrolledAt, DateTime.parse('2024-01-15T09:00:00Z'));
        expect(
            enrollment.expiresAt, DateTime.parse(futureDate.toIso8601String()));
        expect(enrollment.isActive, true);
        expect(enrollment.completionPercentage, 45.8);
        expect(enrollment.course, isNull);
      });

      test('fromJson should use defaults for missing optional fields', () {
        final minimalJson = {
          'id': 'minimal-enrollment',
          'user_id': 'minimal-user',
          'course_id': 'minimal-course',
          'enrolled_at': '2024-01-01T00:00:00Z',
          'expires_at': '2025-01-01T00:00:00Z',
        };

        final enrollment = EnrolledCourse.fromJson(minimalJson);

        expect(enrollment.isActive, true);
        expect(enrollment.completionPercentage, 0.0);
        expect(enrollment.course, isNull);
      });

      test('fromJson should parse nested course data', () {
        final jsonWithCourse = Map<String, dynamic>.from(testJson);
        jsonWithCourse['course'] = {
          'id': 'course-nested',
          'course_number': 'NESTED-101',
          'title': 'Nested Course',
          'gradient_start_color': '#FF0000',
          'gradient_end_color': '#00FF00',
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        final enrollment = EnrolledCourse.fromJson(jsonWithCourse);

        expect(enrollment.course, isNotNull);
        expect(enrollment.course!.id, 'course-nested');
        expect(enrollment.course!.courseNumber, 'NESTED-101');
        expect(enrollment.course!.title, 'Nested Course');
      });

      test('toJson should serialize all fields correctly', () {
        final enrollment = EnrolledCourse.fromJson(testJson);
        final json = enrollment.toJson();

        expect(json['id'], 'enrollment-xyz123');
        expect(json['user_id'], 'user-abc456');
        expect(json['course_id'], 'course-def789');
        expect(json['enrolled_at'], '2024-01-15T09:00:00.000Z');
        expect(json['is_active'], true);
        expect(json['completion_percentage'], 45.8);
        expect(json.containsKey('course'), false); // No nested course
      });

      test('toJson should include nested course when present', () {
        final testCourse = Course(
          id: 'course-123',
          courseNumber: 'TEST-101',
          title: 'Test Course',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          course: testCourse,
        );

        final json = enrollment.toJson();

        expect(json.containsKey('course'), true);
        expect(json['course']['id'], 'course-123');
        expect(json['course']['title'], 'Test Course');
      });

      test('round-trip serialization should preserve data', () {
        final original = EnrolledCourse.fromJson(testJson);
        final json = original.toJson();
        final restored = EnrolledCourse.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.userId, original.userId);
        expect(restored.courseId, original.courseId);
        expect(restored.isActive, original.isActive);
        expect(restored.completionPercentage, original.completionPercentage);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = EnrolledCourse.fromJson(testJson);
        final updated = original.copyWith(
          completionPercentage: 80.0,
          isActive: false,
        );

        expect(updated.id, original.id);
        expect(updated.userId, original.userId);
        expect(updated.completionPercentage, 80.0);
        expect(updated.isActive, false);
        expect(updated.courseId, original.courseId);
      });

      test('should preserve original when no fields changed', () {
        final original = EnrolledCourse.fromJson(testJson);
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.completionPercentage, original.completionPercentage);
        expect(copy.isActive, original.isActive);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final now = DateTime.now();
        final enrollment1 = EnrolledCourse(
          id: 'same-id',
          userId: 'user-1',
          courseId: 'course-1',
          enrolledAt: now,
          expiresAt: futureDate,
          completionPercentage: 50.0,
        );

        final enrollment2 = EnrolledCourse(
          id: 'same-id',
          userId: 'user-2',
          courseId: 'course-2',
          enrolledAt: now,
          expiresAt: pastDate,
          completionPercentage: 80.0,
        );

        expect(enrollment1, equals(enrollment2));
        expect(enrollment1.hashCode, enrollment2.hashCode);
      });

      test('should not be equal when IDs differ', () {
        final now = DateTime.now();
        final enrollment1 = EnrolledCourse(
          id: 'id-1',
          userId: 'same-user',
          courseId: 'same-course',
          enrolledAt: now,
          expiresAt: futureDate,
        );

        final enrollment2 = EnrolledCourse(
          id: 'id-2',
          userId: 'same-user',
          courseId: 'same-course',
          enrolledAt: now,
          expiresAt: futureDate,
        );

        expect(enrollment1, isNot(equals(enrollment2)));
      });

      test('should be equal to itself', () {
        final enrollment = EnrolledCourse.fromJson(testJson);
        expect(enrollment, equals(enrollment));
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final enrollment = EnrolledCourse(
          id: 'test-123',
          userId: 'user-456',
          courseId: 'course-789',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          completionPercentage: 67.5,
        );

        final str = enrollment.toString();
        expect(str, contains('test-123'));
        expect(str, contains('course-789'));
        expect(str, contains('67.5%'));
      });
    });

    group('Edge Cases', () {
      test('should handle very high completion percentages', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          completionPercentage: 999.9,
        );

        expect(enrollment.completionStatus, 'Completed');
        expect(enrollment.completionPercentage, 999.9);
      });

      test('should handle negative completion percentages', () {
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: DateTime.now(),
          expiresAt: futureDate,
          completionPercentage: -5.0,
        );

        expect(enrollment.completionStatus, 'Not Started');
        expect(enrollment.completionPercentage, -5.0);
      });

      test('should handle same enrollment and expiration dates', () {
        final now = DateTime.now();
        final enrollment = EnrolledCourse(
          id: 'test',
          userId: 'user',
          courseId: 'course',
          enrolledAt: now,
          expiresAt: now,
        );

        // Should be expired (not after, but not before either)
        expect(enrollment.isExpired, isTrue);
        expect(enrollment.daysRemaining, 0);
      });
    });

    group('Validation Function', () {
      test('validateEnrolledCourseModel should not throw', () {
        expect(() => validateEnrolledCourseModel(), returnsNormally);
      });
    });
  });
}
