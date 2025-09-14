/// Assignment Model
///
/// Purpose: Represents an assignment within a course
/// Dependencies: None
///
/// Usage:
///   final assignment = Assignment.fromJson(jsonData);
///   final displayNumber = assignment.assignmentNumber;
///
/// Expected behavior:
///   - Maintains assignment ordering within courses
///   - Provides display number for UI presentation
///   - Supports expandable tile functionality

class Assignment {
  final String id;
  final String courseId;
  final int assignmentNumber;
  final String title;
  final String? description;
  final int orderIndex;
  final DateTime createdAt;

  Assignment({
    required this.id,
    required this.courseId,
    required this.assignmentNumber,
    required this.title,
    this.description,
    required this.orderIndex,
    required this.createdAt,
  });

  /// Display string for assignment number
  String get displayNumber => assignmentNumber.toString();

  /// Creates Assignment from JSON map
  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      assignmentNumber: json['assignment_number'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      orderIndex: json['order_index'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
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
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  Assignment copyWith({
    String? id,
    String? courseId,
    int? assignmentNumber,
    String? title,
    String? description,
    int? orderIndex,
    DateTime? createdAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      assignmentNumber: assignmentNumber ?? this.assignmentNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
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
  // Test JSON parsing
  final testJson = {
    'id': 'assignment-123',
    'course_id': 'course-456',
    'assignment_number': 1,
    'title': 'Introduction to Risk Assessment',
    'description': 'Learn the fundamentals of risk assessment',
    'order_index': 0,
    'created_at': '2024-01-01T00:00:00Z',
  };

  final assignment = Assignment.fromJson(testJson);
  assert(assignment.id == 'assignment-123');
  assert(assignment.courseId == 'course-456');
  assert(assignment.assignmentNumber == 1);
  assert(assignment.displayNumber == '1');
  assert(assignment.title == 'Introduction to Risk Assessment');

  // Test serialization
  final json = assignment.toJson();
  assert(json['id'] == 'assignment-123');
  assert(json['assignment_number'] == 1);

  // Test copyWith
  final updated = assignment.copyWith(title: 'Updated Title');
  assert(updated.title == 'Updated Title');
  assert(updated.id == assignment.id);
}
