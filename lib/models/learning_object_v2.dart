/// Learning Object Model V2
///
/// Purpose: Represents individual learning content aligned with database schema
/// Dependencies: word_timing.dart, sentence_timing.dart, content_metadata.dart
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 3)
///   - Direct database mapping with JSONB fields
///   - Supports pre-processed content from pipeline
///   - Includes progress fields from user_progress join
///
/// Usage:
///   final learningObject = LearningObjectV2.fromJson(jsonData);
///   final wordTimings = learningObject.wordTimings;

import 'word_timing.dart';
import 'sentence_timing.dart';
import 'content_metadata.dart';

class LearningObjectV2 {
  final String id;
  final String assignmentId;
  final String courseId;
  final String title;
  final int orderIndex;

  // Content fields (from JSONB)
  final String displayText;
  final List<String> paragraphs;
  final List<String> headers;
  final ContentFormatting formatting;
  final ContentMetadata metadata;

  // Timing fields (from JSONB)
  final List<WordTiming> wordTimings;
  final List<SentenceTiming> sentenceTimings;
  final int totalDurationMs;

  // Audio fields
  final String audioUrl;
  final int audioSizeBytes;
  final String audioFormat;

  // Version control
  final int fileVersion;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Progress fields (from user_progress join, optional)
  final bool? isCompleted;
  final bool? isInProgress;
  final int? currentPositionMs;
  final int? lastWordIndex;
  final int? lastSentenceIndex;
  final double? playbackSpeed;

  LearningObjectV2({
    required this.id,
    required this.assignmentId,
    required this.courseId,
    required this.title,
    required this.orderIndex,
    required this.displayText,
    required this.paragraphs,
    required this.headers,
    required this.formatting,
    required this.metadata,
    required this.wordTimings,
    required this.sentenceTimings,
    required this.totalDurationMs,
    required this.audioUrl,
    required this.audioSizeBytes,
    required this.audioFormat,
    required this.fileVersion,
    required this.createdAt,
    required this.updatedAt,
    this.isCompleted,
    this.isInProgress,
    this.currentPositionMs,
    this.lastWordIndex,
    this.lastSentenceIndex,
    this.playbackSpeed,
  });

  /// Check if content has word timings
  bool get hasWordTimings => wordTimings.isNotEmpty;

  /// Check if content has sentence timings
  bool get hasSentenceTimings => sentenceTimings.isNotEmpty;

  /// Get progress percentage
  double get progressPercentage {
    if (totalDurationMs == 0 || currentPositionMs == null) return 0.0;
    return (currentPositionMs! / totalDurationMs * 100).clamp(0.0, 100.0);
  }

  /// Get audio size in MB
  String get audioSizeMB {
    final mb = audioSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Creates LearningObjectV2 from JSON map
  factory LearningObjectV2.fromJson(Map<String, dynamic> json) {
    // Data comes flat from database - no nested 'content' object
    final displayText = json['display_text'] as String? ?? '';
    final paragraphs = (json['paragraphs'] as List?)
            ?.map((p) => p as String)
            .toList() ??
        [];
    final headers =
        (json['headers'] as List?)?.map((h) => h as String).toList() ??
            [];

    // Parse formatting JSONB
    final formattingJson = json['formatting'];
    final formatting = formattingJson != null
        ? ContentFormatting.fromJson(Map<String, dynamic>.from(formattingJson))
        : ContentFormatting();

    // Parse metadata JSONB
    final metadataJson = json['metadata'];
    final metadata = metadataJson != null
        ? ContentMetadata.fromJson(Map<String, dynamic>.from(metadataJson))
        : ContentMetadata(
            wordCount: 0,
            characterCount: 0,
            estimatedReadingTime: '0 min',
            language: 'en',
          );

    // Parse word timings JSONB
    final wordTimingsJson = json['word_timings'] as List?;
    final wordTimings = wordTimingsJson
            ?.map((w) => WordTiming.fromJson(w as Map<String, dynamic>))
            .toList() ??
        [];

    // Parse sentence timings JSONB
    final sentenceTimingsJson = json['sentence_timings'] as List?;
    final sentenceTimings = sentenceTimingsJson
            ?.map((s) => SentenceTiming.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return LearningObjectV2(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      displayText: displayText,
      paragraphs: paragraphs,
      headers: headers,
      formatting: formatting,
      metadata: metadata,
      wordTimings: wordTimings,
      sentenceTimings: sentenceTimings,
      totalDurationMs: json['total_duration_ms'] as int? ?? 0,
      audioUrl: json['audio_url'] as String? ?? '',
      audioSizeBytes: json['audio_size_bytes'] as int? ?? 0,
      audioFormat: json['audio_format'] as String? ?? 'mp3',
      fileVersion: json['file_version'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Progress fields (may be null if not joined)
      isCompleted: json['is_completed'] as bool?,
      isInProgress: json['is_in_progress'] as bool?,
      currentPositionMs: json['current_position_ms'] as int?,
      lastWordIndex: json['last_word_index'] as int?,
      lastSentenceIndex: json['last_sentence_index'] as int?,
      playbackSpeed: json['playback_speed'] as double?,
    );
  }

  /// Converts LearningObjectV2 to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'course_id': courseId,
      'title': title,
      'order_index': orderIndex,
      'display_text': displayText,
      'paragraphs': paragraphs,
      'headers': headers,
      'formatting': formatting.toJson(),
      'metadata': metadata.toJson(),
      'word_timings': wordTimings.map((w) => w.toJson()).toList(),
      'sentence_timings': sentenceTimings.map((s) => s.toJson()).toList(),
      'total_duration_ms': totalDurationMs,
      'audio_url': audioUrl,
      'audio_size_bytes': audioSizeBytes,
      'audio_format': audioFormat,
      'file_version': fileVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Include progress fields if present
      if (isCompleted != null) 'is_completed': isCompleted,
      if (isInProgress != null) 'is_in_progress': isInProgress,
      if (currentPositionMs != null) 'current_position_ms': currentPositionMs,
      if (lastWordIndex != null) 'last_word_index': lastWordIndex,
      if (lastSentenceIndex != null) 'last_sentence_index': lastSentenceIndex,
      if (playbackSpeed != null) 'playback_speed': playbackSpeed,
    };
  }

  /// Creates a copy with updated fields
  LearningObjectV2 copyWith({
    String? id,
    String? assignmentId,
    String? courseId,
    String? title,
    int? orderIndex,
    String? displayText,
    List<String>? paragraphs,
    List<String>? headers,
    ContentFormatting? formatting,
    ContentMetadata? metadata,
    List<WordTiming>? wordTimings,
    List<SentenceTiming>? sentenceTimings,
    int? totalDurationMs,
    String? audioUrl,
    int? audioSizeBytes,
    String? audioFormat,
    int? fileVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    bool? isInProgress,
    int? currentPositionMs,
    int? lastWordIndex,
    int? lastSentenceIndex,
    double? playbackSpeed,
  }) {
    return LearningObjectV2(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
      displayText: displayText ?? this.displayText,
      paragraphs: paragraphs ?? this.paragraphs,
      headers: headers ?? this.headers,
      formatting: formatting ?? this.formatting,
      metadata: metadata ?? this.metadata,
      wordTimings: wordTimings ?? this.wordTimings,
      sentenceTimings: sentenceTimings ?? this.sentenceTimings,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      audioUrl: audioUrl ?? this.audioUrl,
      audioSizeBytes: audioSizeBytes ?? this.audioSizeBytes,
      audioFormat: audioFormat ?? this.audioFormat,
      fileVersion: fileVersion ?? this.fileVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isInProgress: isInProgress ?? this.isInProgress,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      lastWordIndex: lastWordIndex ?? this.lastWordIndex,
      lastSentenceIndex: lastSentenceIndex ?? this.lastSentenceIndex,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  @override
  String toString() {
    return 'LearningObjectV2(id: $id, title: $title, progress: ${progressPercentage.toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LearningObjectV2 && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify LearningObjectV2 model implementation
void validateLearningObjectV2Model() {
  // Test JSON parsing with full structure
  final testJson = {
    'id': 'lo-123',
    'assignment_id': 'assignment-456',
    'course_id': 'course-789',
    'title': 'Chapter 1: Introduction',
    'order_index': 0,
    'content': {
      'display_text': 'Hello world.\nThis is a test.',
      'paragraphs': ['Hello world.', 'This is a test.'],
      'headers': [],
    },
    'formatting': {
      'bold_headers': false,
      'paragraph_spacing': true,
    },
    'metadata': {
      'word_count': 5,
      'character_count': 28,
      'estimated_reading_time': '1 minute',
      'language': 'en',
    },
    'word_timings': [
      {
        'word': 'Hello',
        'start_ms': 0,
        'end_ms': 500,
        'sentence_index': 0,
        'char_start': 0,
        'char_end': 5,
      },
      {
        'word': 'world',
        'start_ms': 500,
        'end_ms': 1000,
        'sentence_index': 0,
        'char_start': 6,
        'char_end': 11,
      },
    ],
    'sentence_timings': [
      {
        'text': 'Hello world.',
        'start_ms': 0,
        'end_ms': 1500,
        'sentence_index': 0,
        'word_start_index': 0,
        'word_end_index': 1,
        'char_start': 0,
        'char_end': 12,
      },
    ],
    'total_duration_ms': 5000,
    'audio_url': 'https://example.com/audio.mp3',
    'audio_size_bytes': 1048576, // 1 MB
    'audio_format': 'mp3',
    'file_version': 1,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
    'is_in_progress': true,
    'current_position_ms': 2500,
  };

  final learningObject = LearningObjectV2.fromJson(testJson);
  assert(learningObject.id == 'lo-123');
  assert(learningObject.title == 'Chapter 1: Introduction');
  assert(learningObject.displayText == 'Hello world.\nThis is a test.');
  assert(learningObject.paragraphs.length == 2);
  assert(learningObject.metadata.wordCount == 5);
  assert(learningObject.wordTimings.length == 2);
  assert(learningObject.sentenceTimings.length == 1);
  assert(learningObject.hasWordTimings == true);
  assert(learningObject.hasSentenceTimings == true);
  assert(learningObject.progressPercentage == 50.0);
  assert(learningObject.audioSizeMB == '1.0 MB');

  // Test serialization
  final json = learningObject.toJson();
  assert(json['id'] == 'lo-123');
  assert((json['content'] as Map)['display_text'] ==
      'Hello world.\nThis is a test.');
  assert((json['metadata'] as Map)['word_count'] == 5);
  assert((json['word_timings'] as List).length == 2);
}
