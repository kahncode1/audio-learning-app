/// Course Model
///
/// Purpose: Represents an educational course with visual gradient styling
/// Dependencies:
///   - Flutter Material for LinearGradient
///
/// Usage:
///   final course = Course.fromJson(jsonData);
///   final gradient = course.gradient;
///
/// Expected behavior:
///   - Parses course data from Supabase JSON
///   - Provides LinearGradient for UI rendering
///   - Supports serialization for caching

import 'package:flutter/material.dart';

class Course {
  final String id;
  final String courseNumber;
  final String title;
  final String? description;
  final String gradientStartColor;
  final String gradientEndColor;
  final int totalDurationMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  Course({
    required this.id,
    required this.courseNumber,
    required this.title,
    this.description,
    this.gradientStartColor = '#2196F3',
    this.gradientEndColor = '#1976D2',
    this.totalDurationMs = 0,
    required this.createdAt,
    required this.updatedAt,
  });

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

  /// Creates Course from JSON map
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      courseNumber: json['course_number'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      gradientStartColor: json['gradient_start_color'] as String? ?? '#2196F3',
      gradientEndColor: json['gradient_end_color'] as String? ?? '#1976D2',
      totalDurationMs: json['total_duration_ms'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts Course to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_number': courseNumber,
      'title': title,
      'description': description,
      'gradient_start_color': gradientStartColor,
      'gradient_end_color': gradientEndColor,
      'total_duration_ms': totalDurationMs,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  Course copyWith({
    String? id,
    String? courseNumber,
    String? title,
    String? description,
    String? gradientStartColor,
    String? gradientEndColor,
    int? totalDurationMs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      courseNumber: courseNumber ?? this.courseNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      gradientStartColor: gradientStartColor ?? this.gradientStartColor,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
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
  // Test JSON parsing
  final testJson = {
    'id': 'test-id-123',
    'course_number': 'COURSE-101',
    'title': 'Test Course',
    'description': 'Test Description',
    'gradient_start_color': '#FF5722',
    'gradient_end_color': '#E64A19',
    'total_duration_ms': 3600000,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
  };

  final course = Course.fromJson(testJson);
  assert(course.id == 'test-id-123');
  assert(course.courseNumber == 'COURSE-101');
  assert(course.title == 'Test Course');
  assert(course.gradientStartColor == '#FF5722');

  // Test gradient generation
  final gradient = course.gradient;
  assert(gradient.colors.length == 2);

  // Test serialization
  final json = course.toJson();
  assert(json['id'] == 'test-id-123');
  assert(json['course_number'] == 'COURSE-101');

  // Test copyWith
  final updated = course.copyWith(title: 'Updated Title');
  assert(updated.title == 'Updated Title');
  assert(updated.id == course.id);
}
