/// Assignment Model
///
/// Purpose: Represents an assignment within a course aligned with database schema
/// Dependencies: None
///
/// Status: ✅ Updated for DATA_ARCHITECTURE_PLAN (Phase 3)
///   - Direct database mapping with metrics fields
///   - Includes learning object count and total duration
///
/// Usage:
///   final assignment = Assignment.fromJson(jsonData);
///   final displayNumber = assignment.assignmentNumber;
///
/// Expected behavior:
///   - Direct mapping from Supabase assignments table
///   - Provides assignment-level metrics
///   - Supports expandable tile functionality

class Assignment {
  final String id;
  final String courseId;
  final int assignmentNumber;
  final String title;
  final String? description;
  final int learningObjectCount;
  final int totalDurationMs;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    required this.id,
    required this.courseId,
    required this.assignmentNumber,
    required this.title,
    this.description,
    this.learningObjectCount = 0,
    this.totalDurationMs = 0,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display string for assignment number
  String get displayNumber => assignmentNumber.toString();

  /// Format duration from milliseconds to readable string
  String get formattedDuration {
    if (totalDurationMs == 0) return '0 min';
    final hours = totalDurationMs ~/ 3600000;
    final minutes = (totalDurationMs % 3600000) ~/ 60000;
    if (hours > 0) {
      if (minutes > 0) {
        return '$hours hr $minutes min';
      }
      return '$hours hr';
    }
    return '$minutes min';
  }

  /// Creates Assignment from JSON map
  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      assignmentNumber: json['assignment_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      learningObjectCount: json['learning_object_count'] as int? ?? 0,
      totalDurationMs: json['total_duration_ms'] as int? ?? 0,
      orderIndex: json['order_index'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts Assignment to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'assignment_number': assignmentNumber,
      'title': title,
      'description': description,
      'learning_object_count': learningObjectCount,
      'total_duration_ms': totalDurationMs,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  Assignment copyWith({
    String? id,
    String? courseId,
    int? assignmentNumber,
    String? title,
    String? description,
    int? learningObjectCount,
    int? totalDurationMs,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      assignmentNumber: assignmentNumber ?? this.assignmentNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      learningObjectCount: learningObjectCount ?? this.learningObjectCount,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Assignment(id: $id, number: $assignmentNumber, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Assignment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify Assignment model implementation
void validateAssignmentModel() {
  // Test JSON parsing with new fields
  final testJson = {
    'id': 'assignment-123',
    'course_id': 'course-456',
    'assignment_number': 1,
    'title': 'Introduction to Risk Assessment',
    'description': 'Learn the fundamentals of risk assessment',
    'learning_object_count': 5,
    'total_duration_ms': 1800000, // 30 minutes
    'order_index': 0,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-02T00:00:00Z',
  };

  final assignment = Assignment.fromJson(testJson);
  assert(assignment.id == 'assignment-123');
  assert(assignment.courseId == 'course-456');
  assert(assignment.assignmentNumber == 1);
  assert(assignment.displayNumber == '1');
  assert(assignment.title == 'Introduction to Risk Assessment');
  assert(assignment.learningObjectCount == 5);
  assert(assignment.totalDurationMs == 1800000);
  assert(assignment.formattedDuration == '30 min');

  // Test serialization
  final json = assignment.toJson();
  assert(json['id'] == 'assignment-123');
  assert(json['assignment_number'] == 1);
  assert(json['learning_object_count'] == 5);
  assert(json['total_duration_ms'] == 1800000);

  // Test copyWith
  final updated = assignment.copyWith(
    title: 'Updated Title',
    learningObjectCount: 7,
  );
  assert(updated.title == 'Updated Title');
  assert(updated.learningObjectCount == 7);
  assert(updated.id == assignment.id);

  // Test duration formatting
  final longAssignment =
      assignment.copyWith(totalDurationMs: 5400000); // 1hr 30min
  assert(longAssignment.formattedDuration == '1 hr 30 min');
}
