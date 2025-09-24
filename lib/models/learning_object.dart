/// Learning Object Model
///
/// Purpose: Represents individual learning content with audio and word timing data
/// Dependencies: word_timing.dart
///
/// Usage:
///   final learningObject = LearningObject.fromJson(jsonData);
///   final timings = learningObject.wordTimings;
///
/// Expected behavior:
///   - Stores plain text content for display
///   - Contains word timing data for synchronization
///   - Tracks progress state

import 'word_timing.dart';

class LearningObject {
  final String id;
  final String assignmentId;
  final String title;
  final String contentType;
  final String? ssmlContent;
  final String? plainText;
  final List<WordTiming>? wordTimings;
  final int durationMs;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Progress tracking fields (populated from progress table)
  final bool isCompleted;
  final bool isInProgress;
  final int currentPositionMs;

  LearningObject({
    required this.id,
    required this.assignmentId,
    required this.title,
    this.contentType = 'text',
    this.ssmlContent,
    this.plainText,
    this.wordTimings,
    this.durationMs = 0,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
    this.isCompleted = false,
    this.isInProgress = false,
    this.currentPositionMs = 0,
  });

  /// Check if content has word timings
  bool get hasWordTimings => wordTimings != null && wordTimings!.isNotEmpty;

  /// Get progress percentage
  double get progressPercentage {
    if (durationMs == 0) return 0.0;
    return (currentPositionMs / durationMs * 100).clamp(0.0, 100.0);
  }

  /// Creates LearningObject from JSON map
  factory LearningObject.fromJson(Map<String, dynamic> json) {
    List<WordTiming>? timings;

    // Parse word timings if present
    if (json['word_timings'] != null) {
      if (json['word_timings'] is List) {
        timings = (json['word_timings'] as List)
            .map(
                (timing) => WordTiming.fromJson(timing as Map<String, dynamic>))
            .toList();
      } else if (json['word_timings'] is Map) {
        // Handle JSONB format from Supabase
        final timingsData = json['word_timings'] as Map<String, dynamic>;
        if (timingsData['timings'] != null) {
          timings = (timingsData['timings'] as List)
              .map((timing) =>
                  WordTiming.fromJson(timing as Map<String, dynamic>))
              .toList();
        }
      }
    }

    return LearningObject(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      title: json['title'] as String,
      contentType: json['content_type'] as String? ?? 'text',
      ssmlContent: json['ssml_content'] as String?,
      plainText: json['plain_text'] as String?,
      wordTimings: timings,
      durationMs: json['duration_ms'] as int? ?? 0,
      orderIndex: json['order_index'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isCompleted: json['is_completed'] as bool? ?? false,
      isInProgress: json['is_in_progress'] as bool? ?? false,
      currentPositionMs: json['current_position_ms'] as int? ?? 0,
    );
  }

  /// Converts LearningObject to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'title': title,
      'content_type': contentType,
      'ssml_content': ssmlContent,
      'plain_text': plainText,
      'word_timings': wordTimings != null
          ? {
              'timings': wordTimings!.map((timing) => timing.toJson()).toList(),
            }
          : null,
      'duration_ms': durationMs,
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_completed': isCompleted,
      'is_in_progress': isInProgress,
      'current_position_ms': currentPositionMs,
    };
  }

  /// Creates a copy with updated fields
  LearningObject copyWith({
    String? id,
    String? assignmentId,
    String? title,
    String? contentType,
    String? ssmlContent,
    String? plainText,
    List<WordTiming>? wordTimings,
    int? durationMs,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    bool? isInProgress,
    int? currentPositionMs,
  }) {
    return LearningObject(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      title: title ?? this.title,
      contentType: contentType ?? this.contentType,
      ssmlContent: ssmlContent ?? this.ssmlContent,
      plainText: plainText ?? this.plainText,
      wordTimings: wordTimings ?? this.wordTimings,
      durationMs: durationMs ?? this.durationMs,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isInProgress: isInProgress ?? this.isInProgress,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
    );
  }

  @override
  String toString() {
    return 'LearningObject(id: $id, title: $title, progress: ${progressPercentage.toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearningObject && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify LearningObject model implementation
void validateLearningObjectModel() {
  // Test JSON parsing without word timings
  final testJson = {
    'id': 'lo-123',
    'assignment_id': 'assignment-456',
    'title': 'Chapter 1: Introduction',
    'content_type': 'text',
    'ssml_content': null, // Not used in download-first architecture
    'plain_text': 'Hello world',
    'duration_ms': 5000,
    'order_index': 0,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
    'is_in_progress': true,
    'current_position_ms': 2500,
  };

  final learningObject = LearningObject.fromJson(testJson);
  assert(learningObject.id == 'lo-123');
  assert(learningObject.title == 'Chapter 1: Introduction');
  assert(learningObject.isInProgress == true);
  assert(learningObject.progressPercentage == 50.0);
  assert(!learningObject.hasWordTimings);

  // Test with word timings
  final jsonWithTimings = Map<String, dynamic>.from(testJson);
  jsonWithTimings['word_timings'] = {
    'timings': [
      {'word': 'Hello', 'start_ms': 0, 'end_ms': 500, 'sentence_index': 0},
      {'word': 'world', 'start_ms': 500, 'end_ms': 1000, 'sentence_index': 0},
    ]
  };

  final withTimings = LearningObject.fromJson(jsonWithTimings);
  assert(withTimings.hasWordTimings);
  assert(withTimings.wordTimings!.length == 2);

  // Test serialization
  final json = learningObject.toJson();
  assert(json['id'] == 'lo-123');
  assert(json['is_in_progress'] == true);
}
