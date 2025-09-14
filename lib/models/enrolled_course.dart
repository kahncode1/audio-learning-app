/// Enrolled Course Model
///
/// Purpose: Represents a user's enrollment in a course with expiration
/// Dependencies: course.dart
///
/// Usage:
///   final enrollment = EnrolledCourse.fromJson(jsonData);
///   final isActive = enrollment.isActive;
///
/// Expected behavior:
///   - Tracks enrollment status and expiration
///   - Monitors completion percentage
///   - Supports automatic expiration filtering

import 'course.dart';

class EnrolledCourse {
  final String id;
  final String userId;
  final String courseId;
  final DateTime enrolledAt;
  final DateTime expiresAt;
  final bool isActive;
  final double completionPercentage;
  final Course? course; // Populated when joined with courses table

  EnrolledCourse({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.enrolledAt,
    required this.expiresAt,
    this.isActive = true,
    this.completionPercentage = 0.0,
    this.course,
  });

  /// Check if enrollment has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if enrollment is valid (active and not expired)
  bool get isValid => isActive && !isExpired;

  /// Days remaining until expiration
  int get daysRemaining {
    if (isExpired) return 0;
    return expiresAt.difference(DateTime.now()).inDays;
  }

  /// Formatted expiration date
  String get formattedExpirationDate {
    return '${expiresAt.month}/${expiresAt.day}/${expiresAt.year}';
  }

  /// Get completion status
  String get completionStatus {
    if (completionPercentage >= 100) return 'Completed';
    if (completionPercentage > 0) return 'In Progress';
    return 'Not Started';
  }

  /// Creates EnrolledCourse from JSON map
  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    Course? course;

    // Parse nested course data if present
    if (json['course'] != null) {
      course = Course.fromJson(json['course'] as Map<String, dynamic>);
    } else if (json['courses'] != null) {
      // Handle Supabase join format
      course = Course.fromJson(json['courses'] as Map<String, dynamic>);
    }

    return EnrolledCourse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      completionPercentage:
          (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      course: course,
    );
  }

  /// Converts EnrolledCourse to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'course_id': courseId,
      'enrolled_at': enrolledAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_active': isActive,
      'completion_percentage': completionPercentage,
      if (course != null) 'course': course!.toJson(),
    };
  }

  /// Creates a copy with updated fields
  EnrolledCourse copyWith({
    String? id,
    String? userId,
    String? courseId,
    DateTime? enrolledAt,
    DateTime? expiresAt,
    bool? isActive,
    double? completionPercentage,
    Course? course,
  }) {
    return EnrolledCourse(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      course: course ?? this.course,
    );
  }

  @override
  String toString() {
    return 'EnrolledCourse(id: $id, courseId: $courseId, completion: ${completionPercentage.toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnrolledCourse && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify EnrolledCourse model implementation
void validateEnrolledCourseModel() {
  // Test JSON parsing without course
  final testJson = {
    'id': 'enrollment-123',
    'user_id': 'user-456',
    'course_id': 'course-789',
    'enrolled_at': '2024-01-01T00:00:00Z',
    'expires_at': '2025-01-01T00:00:00Z',
    'is_active': true,
    'completion_percentage': 75.5,
  };

  final enrollment = EnrolledCourse.fromJson(testJson);
  assert(enrollment.id == 'enrollment-123');
  assert(enrollment.userId == 'user-456');
  assert(enrollment.completionPercentage == 75.5);
  assert(enrollment.completionStatus == 'In Progress');
  assert(enrollment.isActive == true);

  // Test with future expiration
  final futureDate = DateTime.now().add(const Duration(days: 30));
  final activeEnrollment = enrollment.copyWith(expiresAt: futureDate);
  assert(activeEnrollment.isValid == true);
  assert(activeEnrollment.isExpired == false);
  assert(activeEnrollment.daysRemaining > 0);

  // Test with past expiration
  final pastDate = DateTime.now().subtract(const Duration(days: 1));
  final expiredEnrollment = enrollment.copyWith(expiresAt: pastDate);
  assert(expiredEnrollment.isExpired == true);
  assert(expiredEnrollment.isValid == false);
  assert(expiredEnrollment.daysRemaining == 0);

  // Test with nested course data
  final jsonWithCourse = Map<String, dynamic>.from(testJson);
  jsonWithCourse['course'] = {
    'id': 'course-789',
    'course_number': 'COURSE-101',
    'title': 'Test Course',
    'gradient_start_color': '#2196F3',
    'gradient_end_color': '#1976D2',
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
  };

  final withCourse = EnrolledCourse.fromJson(jsonWithCourse);
  assert(withCourse.course != null);
  assert(withCourse.course!.courseNumber == 'COURSE-101');

  // Test completion statuses
  final notStarted = enrollment.copyWith(completionPercentage: 0.0);
  assert(notStarted.completionStatus == 'Not Started');

  final completed = enrollment.copyWith(completionPercentage: 100.0);
  assert(completed.completionStatus == 'Completed');
}
