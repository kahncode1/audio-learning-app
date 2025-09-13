# /implementations/models.dart

```dart
/// Data Models - Core Domain Models with Enhanced Properties
/// 
/// Provides all data models including:
/// - Course with gradient properties
/// - Assignment with display numbers
/// - LearningObject with in-progress tracking
/// - WordTiming with sentence indices
/// - ProgressState with font preferences

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
class Course with _$Course {
  const factory Course({
    required String courseId,
    required String courseNumber,
    required String courseTitle,
    required int assignmentCount,
    required int learningObjectCount,
    required double completionPercentage,
    required LinearGradient gradient,
    DateTime? expirationDate,
  }) = _Course;
  
  factory Course.fromJson(Map<String, dynamic> json) {
    // Handle gradient conversion
    final gradientStart = json['gradient_start'] ?? '#2196F3';
    final gradientEnd = json['gradient_end'] ?? '#1976D2';
    
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _colorFromHex(gradientStart),
        _colorFromHex(gradientEnd),
      ],
    );
    
    return Course(
      courseId: json['course_id'],
      courseNumber: json['course_number'],
      courseTitle: json['course_title'],
      assignmentCount: json['assignment_count'] ?? 0,
      learningObjectCount: json['learning_object_count'] ?? 0,
      completionPercentage: (json['completion_percentage'] ?? 0.0).toDouble(),
      gradient: gradient,
      expirationDate: json['expiration_date'] != null 
          ? DateTime.parse(json['expiration_date'])
          : null,
    );
  }
  
  static Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

@freezed
class Assignment with _$Assignment {
  const factory Assignment({
    required String id,
    required int number,
    required String title,
    required int learningObjectCount,
    required int durationMinutes,
    required double completionPercentage,
    required List<LearningObject> learningObjects,
    required int orderIndex,
  }) = _Assignment;
  
  factory Assignment.fromJson(Map<String, dynamic> json) {
    final learningObjects = (json['learning_objects'] as List<dynamic>?)
        ?.map((lo) => LearningObject.fromJson(lo as Map<String, dynamic>))
        .toList() ?? [];
    
    return Assignment(
      id: json['id'],
      number: json['assignment_number'] ?? 1,
      title: json['assignment_name'] ?? json['title'] ?? 'Assignment',
      learningObjectCount: learningObjects.length,
      durationMinutes: _calculateTotalDuration(learningObjects),
      completionPercentage: _calculateCompletionPercentage(learningObjects),
      learningObjects: learningObjects,
      orderIndex: json['order_index'] ?? 0,
    );
  }
  
  static int _calculateTotalDuration(List<LearningObject> learningObjects) {
    return learningObjects.fold(0, (sum, lo) => sum + lo.durationMinutes);
  }
  
  static double _calculateCompletionPercentage(List<LearningObject> learningObjects) {
    if (learningObjects.isEmpty) return 0.0;
    
    final completedCount = learningObjects.where((lo) => lo.isCompleted).length;
    return (completedCount / learningObjects.length) * 100;
  }
}

@freezed
class LearningObject with _$LearningObject {
  const factory LearningObject({
    required String loid,
    required String title,
    required int durationMinutes,
    required bool isCompleted,
    @Default(false) bool isInProgress,
    required String ssmlContent,
    List<WordTiming>? wordTimings,
    Duration? lastPosition,
  }) = _LearningObject;
  
  factory LearningObject.fromJson(Map<String, dynamic> json) {
    final wordTimings = json['word_timings'] != null
        ? (json['word_timings'] as List<dynamic>)
            .map((wt) => WordTiming.fromJson(wt as Map<String, dynamic>))
            .toList()
        : null;
    
    return LearningObject(
      loid: json['loid'] ?? json['id'],
      title: json['title'] ?? 'Learning Object',
      durationMinutes: (json['estimated_duration'] ?? 0) ~/ 60,
      isCompleted: json['is_completed'] ?? false,
      isInProgress: json['is_in_progress'] ?? false,
      ssmlContent: json['ssml_content'] ?? '',
      wordTimings: wordTimings,
      lastPosition: json['last_position'] != null
          ? Duration(milliseconds: json['last_position'])
          : null,
    );
  }
}

@freezed
class WordTiming with _$WordTiming {
  const factory WordTiming({
    required String word,
    required int startMs,
    required int endMs,
    required int sentenceIndex,
  }) = _WordTiming;
  
  factory WordTiming.fromJson(Map<String, dynamic> json) => WordTiming(
    word: json['word'],
    startMs: json['startMs'] ?? json['start_ms'],
    endMs: json['endMs'] ?? json['end_ms'],
    sentenceIndex: json['sentenceIndex'] ?? json['sentence_index'] ?? 0,
  );
  
  Map<String, dynamic> toJson() => {
    'word': word,
    'startMs': startMs,
    'endMs': endMs,
    'sentenceIndex': sentenceIndex,
  };
}

@freezed
class ProgressState with _$ProgressState {
  const factory ProgressState({
    required String loid,
    required String userId,
    required Duration position,
    required double playbackSpeed,
    required int fontSizeIndex,
    @Default(false) bool completed,
    required DateTime lastUpdated,
  }) = _ProgressState;
  
  factory ProgressState.fromJson(Map<String, dynamic> json) => ProgressState(
    loid: json['loid'] ?? json['learning_object_id'],
    userId: json['user_id'],
    position: Duration(milliseconds: json['position_ms'] ?? 0),
    playbackSpeed: (json['playback_speed'] ?? 1.5).toDouble(),
    fontSizeIndex: json['font_size_index'] ?? 1,
    completed: json['is_completed'] ?? false,
    lastUpdated: DateTime.parse(json['last_updated']),
  );
  
  Map<String, dynamic> toJson() => {
    'loid': loid,
    'user_id': userId,
    'position_ms': position.inMilliseconds,
    'playback_speed': playbackSpeed,
    'font_size_index': fontSizeIndex,
    'is_completed': completed,
    'last_updated': lastUpdated.toIso8601String(),
  };
}

@freezed
class EnrolledCourse with _$EnrolledCourse {
  const factory EnrolledCourse({
    required String userId,
    required String courseId,
    required DateTime enrollmentDate,
    required DateTime expirationDate,
    required Course course,
  }) = _EnrolledCourse;
  
  factory EnrolledCourse.fromJson(Map<String, dynamic> json) => EnrolledCourse(
    userId: json['user_id'],
    courseId: json['course_id'],
    enrollmentDate: DateTime.parse(json['enrollment_date']),
    expirationDate: DateTime.parse(json['expiration_date']),
    course: Course.fromJson(json['course'] ?? json),
  );
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? firstName,
    String? lastName,
    String? organizationId,
    DateTime? createdAt,
    DateTime? lastSignIn,
  }) = _User;
  
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    email: json['email'],
    firstName: json['first_name'],
    lastName: json['last_name'],
    organizationId: json['organization_id'],
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'])
        : null,
    lastSignIn: json['last_sign_in'] != null
        ? DateTime.parse(json['last_sign_in'])
        : null,
  );
}

// Validation function
void main() {
  print('🔧 Testing Data Models...\n');
  
  final List<String> validationFailures = [];
  int totalTests = 0;
  
  // Test 1: Course JSON serialization/deserialization
  totalTests++;
  final courseJson = {
    'course_id': 'course-123',
    'course_number': 'INS-401',
    'course_title': 'Advanced Insurance Principles',
    'assignment_count': 5,
    'learning_object_count': 20,
    'completion_percentage': 75.5,
    'gradient_start': '#FF0000',
    'gradient_end': '#00FF00',
    'expiration_date': '2025-12-31T23:59:59Z',
  };
  
  try {
    final course = Course.fromJson(courseJson);
    
    if (course.courseId != 'course-123') {
      validationFailures.add('Course ID mismatch: expected course-123, got ${course.courseId}');
    }
    if (course.completionPercentage != 75.5) {
      validationFailures.add('Completion percentage mismatch');
    }
    if (course.gradient.colors.length != 2) {
      validationFailures.add('Gradient not properly created');
    }
    print('✓ Course model serialization working correctly');
  } catch (e) {
    validationFailures.add('Course serialization failed: $e');
  }
  
  // Test 2: Assignment with learning objects
  totalTests++;
  final assignmentJson = {
    'id': 'assignment-1',
    'assignment_number': 2,
    'assignment_name': 'Risk Management Basics',
    'order_index': 1,
    'learning_objects': [
      {
        'loid': 'lo-1',
        'title': 'Introduction to Risk',
        'estimated_duration': 600, // 10 minutes
        'is_completed': true,
        'is_in_progress': false,
        'ssml_content': '<speak>Test content</speak>',
      },
      {
        'loid': 'lo-2',
        'title': 'Risk Assessment',
        'estimated_duration': 900, // 15 minutes
        'is_completed': false,
        'is_in_progress': true,
        'ssml_content': '<speak>More content</speak>',
      },
    ],
  };
  
  try {
    final assignment = Assignment.fromJson(assignmentJson);
    
    if (assignment.number != 2) {
      validationFailures.add('Assignment number incorrect: ${assignment.number}');
    }
    if (assignment.durationMinutes != 25) {
      validationFailures.add('Total duration calculation wrong: ${assignment.durationMinutes}');
    }
    if (assignment.completionPercentage != 50.0) {
      validationFailures.add('Completion percentage wrong: ${assignment.completionPercentage}');
    }
    if (assignment.learningObjects.length != 2) {
      validationFailures.add('Learning objects not loaded');
    }
    print('✓ Assignment model with calculations working');
  } catch (e) {
    validationFailures.add('Assignment serialization failed: $e');
  }
  
  // Test 3: WordTiming with sentence index
  totalTests++;
  final wordTimingJson = {
    'word': 'Hello',
    'start_ms': 0,
    'end_ms': 500,
    'sentence_index': 0,
  };
  
  try {
    final timing = WordTiming.fromJson(wordTimingJson);
    final backToJson = timing.toJson();
    
    if (timing.word != 'Hello') {
      validationFailures.add('Word mismatch in timing');
    }
    if (timing.sentenceIndex != 0) {
      validationFailures.add('Sentence index not preserved');
    }
    if (backToJson['sentenceIndex'] != 0) {
      validationFailures.add('Sentence index not in JSON output');
    }
    print('✓ WordTiming with sentence index working');
  } catch (e) {
    validationFailures.add('WordTiming serialization failed: $e');
  }
  
  // Test 4: ProgressState with font preferences
  totalTests++;
  final progressJson = {
    'loid': 'lo-123',
    'user_id': 'user-456',
    'position_ms': 65000, // 1:05
    'playback_speed': 1.75,
    'font_size_index': 2, // Large
    'is_completed': false,
    'last_updated': '2025-01-15T10:30:00Z',
  };
  
  try {
    final progress = ProgressState.fromJson(progressJson);
    final backToJson = progress.toJson();
    
    if (progress.fontSizeIndex != 2) {
      validationFailures.add('Font size index not preserved: ${progress.fontSizeIndex}');
    }
    if (progress.playbackSpeed != 1.75) {
      validationFailures.add('Playback speed not preserved: ${progress.playbackSpeed}');
    }
    if (progress.position.inSeconds != 65) {
      validationFailures.add('Position not correct: ${progress.position.inSeconds}');
    }
    if (backToJson['font_size_index'] != 2) {
      validationFailures.add('Font size not in JSON output');
    }
    print('✓ ProgressState with preferences working');
  } catch (e) {
    validationFailures.add('ProgressState serialization failed: $e');
  }
  
  // Test 5: LearningObject with in-progress state
  totalTests++;
  final loJson = {
    'loid': 'lo-999',
    'title': 'Test Learning Object',
    'estimated_duration': 1200, // 20 minutes
    'is_completed': false,
    'is_in_progress': true,
    'ssml_content': '<speak>Content here</speak>',
    'last_position': 300000, // 5 minutes
  };
  
  try {
    final learningObject = LearningObject.fromJson(loJson);
    
    if (!learningObject.isInProgress) {
      validationFailures.add('In-progress state not set');
    }
    if (learningObject.lastPosition?.inMinutes != 5) {
      validationFailures.add('Last position not correct');
    }
    if (learningObject.durationMinutes != 20) {
      validationFailures.add('Duration calculation wrong');
    }
    print('✓ LearningObject with in-progress tracking working');
  } catch (e) {
    validationFailures.add('LearningObject serialization failed: $e');
  }
  
  // Final validation results
  print('\n' + '=' * 50);
  if (validationFailures.isNotEmpty) {
    print('❌ VALIDATION FAILED - ${validationFailures.length} of $totalTests tests failed:\n');
    for (final failure in validationFailures) {
      print('  • $failure');
    }
    exit(1);
  } else {
    print('✅ VALIDATION PASSED - All $totalTests tests produced expected results');
    print('All models ready for use with enhanced properties');
    exit(0);
  }
}
```