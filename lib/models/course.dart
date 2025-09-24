/// Course Model
///
/// Purpose: Represents an educational course aligned with database schema
/// Dependencies:
///   - Flutter Material for LinearGradient (UI only)
///
/// Status: ✅ Updated for DATA_ARCHITECTURE_PLAN (Phase 3)
///   - Direct database mapping with new metrics fields
///   - Maintains backward compatibility for gradients
///   - JSON serialization updated for new schema
///
/// Usage:
///   final course = Course.fromJson(jsonData);
///   final gradient = course.gradient;
///
/// Expected behavior:
///   - Direct mapping from Supabase courses table
///   - Provides computed properties for UI
///   - Supports course-level metrics
///
/// Test Coverage:
///   - Unit tests: Pending (model serialization tests needed)
///   - Integration: Working in app with live data
///   - Validation: ✅ Built-in validation function passes

import 'package:flutter/material.dart';

class Course {
  final String id;
  final int? externalCourseId; // External system reference
  final String courseNumber;
  final String title;
  final String? description;
  final int totalLearningObjects;
  final int totalAssignments;
  final int estimatedDurationMs;
  final String? thumbnailUrl;
  final int orderIndex;
  final String gradientStartColor; // Keep for UI compatibility
  final String gradientEndColor; // Keep for UI compatibility
  final DateTime createdAt;
  final DateTime updatedAt;

  Course({
    required this.id,
    this.externalCourseId,
    required this.courseNumber,
    required this.title,
    this.description,
    this.totalLearningObjects = 0,
    this.totalAssignments = 0,
    this.estimatedDurationMs = 0,
    this.thumbnailUrl,
    this.orderIndex = 0,
    this.gradientStartColor = '#2196F3',
    this.gradientEndColor = '#1976D2',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Computed property for estimated duration display
  String get estimatedDuration => _formatDuration(estimatedDurationMs);

  /// Creates LinearGradient from color strings
  LinearGradient get gradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _colorFromHex(gradientStartColor),
        _colorFromHex(gradientEndColor),
      ],
    );
  }

  /// Converts hex color string to Color
  Color _colorFromHex(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.blue; // Fallback color
  }

  /// Format duration from milliseconds to readable string
  String _formatDuration(int durationMs) {
    if (durationMs == 0) return '0 min';
    final hours = durationMs ~/ 3600000;
    final minutes = (durationMs % 3600000) ~/ 60000;
    if (hours > 0) {
      if (minutes > 0) {
        return '$hours hr $minutes min';
      }
      return '$hours hr';
    }
    return '$minutes min';
  }

  /// Creates Course from JSON map
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      externalCourseId: json['external_course_id'] as int?,
      courseNumber: json['course_number'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      totalLearningObjects: json['total_learning_objects'] as int? ?? 0,
      totalAssignments: json['total_assignments'] as int? ?? 0,
      estimatedDurationMs: json['estimated_duration_ms'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      gradientStartColor: json['gradient_start_color'] as String? ?? '#2196F3',
      gradientEndColor: json['gradient_end_color'] as String? ?? '#1976D2',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts Course to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_course_id': externalCourseId,
      'course_number': courseNumber,
      'title': title,
      'description': description,
      'total_learning_objects': totalLearningObjects,
      'total_assignments': totalAssignments,
      'estimated_duration_ms': estimatedDurationMs,
      'thumbnail_url': thumbnailUrl,
      'order_index': orderIndex,
      'gradient_start_color': gradientStartColor,
      'gradient_end_color': gradientEndColor,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  Course copyWith({
    String? id,
    int? externalCourseId,
    String? courseNumber,
    String? title,
    String? description,
    int? totalLearningObjects,
    int? totalAssignments,
    int? estimatedDurationMs,
    String? thumbnailUrl,
    int? orderIndex,
    String? gradientStartColor,
    String? gradientEndColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      externalCourseId: externalCourseId ?? this.externalCourseId,
      courseNumber: courseNumber ?? this.courseNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      totalLearningObjects: totalLearningObjects ?? this.totalLearningObjects,
      totalAssignments: totalAssignments ?? this.totalAssignments,
      estimatedDurationMs: estimatedDurationMs ?? this.estimatedDurationMs,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      orderIndex: orderIndex ?? this.orderIndex,
      gradientStartColor: gradientStartColor ?? this.gradientStartColor,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Course(id: $id, courseNumber: $courseNumber, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify Course model implementation
void validateCourseModel() {
  // Test JSON parsing with new fields
  final testJson = {
    'id': 'test-id-123',
    'external_course_id': 456,
    'course_number': 'COURSE-101',
    'title': 'Test Course',
    'description': 'Test Description',
    'total_learning_objects': 10,
    'total_assignments': 3,
    'estimated_duration_ms': 3600000,
    'thumbnail_url': 'https://example.com/thumb.jpg',
    'order_index': 1,
    'gradient_start_color': '#FF5722',
    'gradient_end_color': '#E64A19',
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
  };

  final course = Course.fromJson(testJson);
  assert(course.id == 'test-id-123');
  assert(course.externalCourseId == 456);
  assert(course.courseNumber == 'COURSE-101');
  assert(course.title == 'Test Course');
  assert(course.totalLearningObjects == 10);
  assert(course.totalAssignments == 3);
  assert(course.estimatedDurationMs == 3600000);
  assert(course.estimatedDuration == '1 hr');
  assert(course.thumbnailUrl == 'https://example.com/thumb.jpg');
  assert(course.orderIndex == 1);
  assert(course.gradientStartColor == '#FF5722');

  // Test gradient generation
  final gradient = course.gradient;
  assert(gradient.colors.length == 2);

  // Test serialization
  final json = course.toJson();
  assert(json['id'] == 'test-id-123');
  assert(json['external_course_id'] == 456);
  assert(json['course_number'] == 'COURSE-101');
  assert(json['total_learning_objects'] == 10);

  // Test copyWith
  final updated =
      course.copyWith(title: 'Updated Title', totalLearningObjects: 15);
  assert(updated.title == 'Updated Title');
  assert(updated.totalLearningObjects == 15);
  assert(updated.id == course.id);

  // Test duration formatting
  assert(course.estimatedDuration == '1 hr');
  final shortCourse = course.copyWith(estimatedDurationMs: 900000); // 15 min
  assert(shortCourse.estimatedDuration == '15 min');
  final longCourse = course.copyWith(estimatedDurationMs: 5400000); // 1hr 30min
  assert(longCourse.estimatedDuration == '1 hr 30 min');

  // All assertions passed - Course model is working correctly
  // Next steps: Create formal unit tests in test/models/course_test.dart
}
