/// User Progress Model
///
/// Purpose: Tracks user progress for learning objects
/// Dependencies: None
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 3)
///   - Direct database mapping from user_progress table
///   - Tracks playback position and completion state
///
/// Usage:
///   final progress = UserProgress.fromJson(jsonData);
///   final percentComplete = progress.progressPercentage;

class UserProgress {
  final String id;
  final String userId;
  final String learningObjectId;
  final String courseId;
  final String assignmentId;

  // Progress tracking
  final int currentPositionMs;
  final int lastWordIndex;
  final int lastSentenceIndex;
  final bool isCompleted;
  final DateTime? completedAt;

  // Playback settings
  final double playbackSpeed;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;

  UserProgress({
    required this.id,
    required this.userId,
    required this.learningObjectId,
    required this.courseId,
    required this.assignmentId,
    this.currentPositionMs = 0,
    this.lastWordIndex = 0,
    this.lastSentenceIndex = 0,
    this.isCompleted = false,
    this.completedAt,
    this.playbackSpeed = 1.0,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAccessedAt,
  });

  /// Check if the user has started this content
  bool get hasStarted => currentPositionMs > 0;

  /// Calculate progress percentage (requires total duration)
  double getProgressPercentage(int totalDurationMs) {
    if (totalDurationMs == 0) return 0.0;
    return (currentPositionMs / totalDurationMs * 100).clamp(0.0, 100.0);
  }

  /// Creates UserProgress from JSON map
  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      learningObjectId: json['learning_object_id'] as String,
      courseId: json['course_id'] as String,
      assignmentId: json['assignment_id'] as String,
      currentPositionMs: json['current_position_ms'] as int? ?? 0,
      lastWordIndex: json['last_word_index'] as int? ?? 0,
      lastSentenceIndex: json['last_sentence_index'] as int? ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      playbackSpeed: json['playback_speed'] as double? ?? 1.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastAccessedAt: DateTime.parse(json['last_accessed_at'] as String),
    );
  }

  /// Converts UserProgress to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'learning_object_id': learningObjectId,
      'course_id': courseId,
      'assignment_id': assignmentId,
      'current_position_ms': currentPositionMs,
      'last_word_index': lastWordIndex,
      'last_sentence_index': lastSentenceIndex,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'playback_speed': playbackSpeed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_accessed_at': lastAccessedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  UserProgress copyWith({
    String? id,
    String? userId,
    String? learningObjectId,
    String? courseId,
    String? assignmentId,
    int? currentPositionMs,
    int? lastWordIndex,
    int? lastSentenceIndex,
    bool? isCompleted,
    DateTime? completedAt,
    double? playbackSpeed,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
  }) {
    return UserProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      learningObjectId: learningObjectId ?? this.learningObjectId,
      courseId: courseId ?? this.courseId,
      assignmentId: assignmentId ?? this.assignmentId,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      lastWordIndex: lastWordIndex ?? this.lastWordIndex,
      lastSentenceIndex: lastSentenceIndex ?? this.lastSentenceIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return 'UserProgress(id: $id, position: $currentPositionMs, completed: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProgress && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify UserProgress model implementation
void validateUserProgressModel() {
  // Test JSON parsing
  final testJson = {
    'id': 'progress-123',
    'user_id': 'user-456',
    'learning_object_id': 'lo-789',
    'course_id': 'course-abc',
    'assignment_id': 'assignment-def',
    'current_position_ms': 30000,
    'last_word_index': 50,
    'last_sentence_index': 5,
    'is_completed': false,
    'completed_at': null,
    'playback_speed': 1.25,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-02T00:00:00Z',
    'last_accessed_at': '2024-01-02T12:00:00Z',
  };

  final progress = UserProgress.fromJson(testJson);
  assert(progress.id == 'progress-123');
  assert(progress.userId == 'user-456');
  assert(progress.currentPositionMs == 30000);
  assert(progress.lastWordIndex == 50);
  assert(progress.playbackSpeed == 1.25);
  assert(progress.hasStarted == true);
  assert(progress.isCompleted == false);
  assert(progress.completedAt == null);

  // Test progress percentage calculation
  assert(progress.getProgressPercentage(60000) == 50.0);
  assert(progress.getProgressPercentage(0) == 0.0);

  // Test serialization
  final json = progress.toJson();
  assert(json['id'] == 'progress-123');
  assert(json['current_position_ms'] == 30000);
  assert(json['playback_speed'] == 1.25);

  // Test copyWith
  final updated = progress.copyWith(
    currentPositionMs: 60000,
    isCompleted: true,
    completedAt: DateTime.now(),
  );
  assert(updated.currentPositionMs == 60000);
  assert(updated.isCompleted == true);
  assert(updated.completedAt != null);
  assert(updated.id == progress.id);

  // Test completed progress
  final completedJson = Map<String, dynamic>.from(testJson);
  completedJson['is_completed'] = true;
  completedJson['completed_at'] = '2024-01-03T00:00:00Z';

  final completedProgress = UserProgress.fromJson(completedJson);
  assert(completedProgress.isCompleted == true);
  assert(completedProgress.completedAt != null);
}