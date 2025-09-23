/// Audio Context Provider - Tracks navigation context for mini player
///
/// Purpose: Maintains course and assignment information for audio playback
/// Dependencies:
///   - flutter_riverpod: State management
///   - models/learning_object: Learning object model
///
/// Features:
///   - Tracks current course information
///   - Maintains assignment details
///   - Provides context for mini player display
///   - Preserves navigation context during playback

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_object_v2.dart';

/// Audio playback context with full navigation information
class AudioContext {
  final String? courseNumber;
  final String? courseTitle;
  final String? assignmentTitle;
  final int? assignmentNumber;
  final LearningObjectV2 learningObject;

  AudioContext({
    this.courseNumber,
    this.courseTitle,
    this.assignmentTitle,
    this.assignmentNumber,
    required this.learningObject,
  });

  /// Create a formatted subtitle for display
  String get formattedSubtitle {
    final parts = <String>[];

    // Add course number if available
    if (courseNumber != null && courseNumber!.isNotEmpty) {
      parts.add(courseNumber!);
    }

    // Add assignment info
    if (assignmentNumber != null) {
      parts.add('Assignment $assignmentNumber');
    } else if (assignmentTitle != null && assignmentTitle!.isNotEmpty) {
      // Use title if number not available
      parts.add(assignmentTitle!);
    }

    // Fallback to generic text if no context
    if (parts.isEmpty) {
      return 'Learning Module';
    }

    return parts.join(' • ');
  }

  /// Copy with updated values
  AudioContext copyWith({
    String? courseNumber,
    String? courseTitle,
    String? assignmentTitle,
    int? assignmentNumber,
    LearningObjectV2? learningObject,
  }) {
    return AudioContext(
      courseNumber: courseNumber ?? this.courseNumber,
      courseTitle: courseTitle ?? this.courseTitle,
      assignmentTitle: assignmentTitle ?? this.assignmentTitle,
      assignmentNumber: assignmentNumber ?? this.assignmentNumber,
      learningObject: learningObject ?? this.learningObject,
    );
  }
}

/// Provider for current audio context
final audioContextProvider = StateProvider<AudioContext?>((ref) => null);

/// Computed provider for mini player subtitle
final miniPlayerSubtitleProvider = Provider<String>((ref) {
  final context = ref.watch(audioContextProvider);
  return context?.formattedSubtitle ?? 'Learning Module';
});

/// Helper to set audio context from navigation arguments
class AudioContextHelper {
  static AudioContext fromNavigationArgs(
    Map<String, dynamic> args,
    LearningObjectV2 learningObject,
  ) {
    return AudioContext(
      courseNumber: args['courseNumber'] as String?,
      courseTitle: args['courseTitle'] as String?,
      assignmentTitle: args['assignmentTitle'] as String?,
      assignmentNumber: args['assignmentNumber'] as int?,
      learningObject: learningObject,
    );
  }

  /// Create context from minimal information
  static AudioContext fromLearningObject(LearningObjectV2 learningObject) {
    return AudioContext(
      learningObject: learningObject,
    );
  }
}