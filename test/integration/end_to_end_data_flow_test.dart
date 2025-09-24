/// End-to-End Data Flow Test
///
/// Purpose: Test complete data flow from database to UI models
/// This test validates Phase 4 service integration

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/course.dart';
import 'package:audio_learning_app/models/assignment.dart';
import 'package:audio_learning_app/models/learning_object_v2.dart';
import 'package:audio_learning_app/models/user_progress.dart';
import 'package:audio_learning_app/models/user_settings.dart';
import 'package:audio_learning_app/models/word_timing.dart';
import 'package:audio_learning_app/models/sentence_timing.dart';

void main() {
  group('End-to-End Data Flow Tests', () {
    test('Complete data flow from JSON to playback ready state', () {
      // Simulate database response with complete structure
      final courseJson = {
        'id': 'course-001',
        'external_course_id': 123,
        'course_number': 'INS-101',
        'title': 'Insurance Fundamentals',
        'description': 'Learn the basics of insurance',
        'total_learning_objects': 10,
        'total_assignments': 3,
        'estimated_duration_ms': 3600000, // 1 hour
        'thumbnail_url': 'https://cdn.example.com/course-thumb.jpg',
        'order_index': 0,
        'gradient_start_color': '#2196F3',
        'gradient_end_color': '#1976D2',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
      };

      final assignmentJson = {
        'id': 'assignment-001',
        'course_id': 'course-001',
        'assignment_number': 1,
        'title': 'Introduction to Risk',
        'description': 'Understanding risk in insurance',
        'learning_object_count': 3,
        'total_duration_ms': 1200000, // 20 minutes
        'order_index': 0,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
      };

      final learningObjectJson = {
        'id': 'lo-001',
        'assignment_id': 'assignment-001',
        'course_id': 'course-001',
        'title': 'What is Risk?',
        'order_index': 0,
        'display_text':
            'Risk is the possibility of loss. Insurance helps manage risk.',
        'paragraphs': [
          'Risk is the possibility of loss.',
          'Insurance helps manage risk.',
        ],
        'headers': [],
        'formatting': {
          'bold_headers': false,
          'paragraph_spacing': true,
        },
        'metadata': {
          'word_count': 10,
          'character_count': 62,
          'estimated_reading_time': '1 min',
          'language': 'en',
        },
        'word_timings': [
          {
            'word': 'Risk',
            'start_ms': 0,
            'end_ms': 400,
            'char_start': 0,
            'char_end': 4,
            'sentence_index': 0
          },
          {
            'word': 'is',
            'start_ms': 400,
            'end_ms': 600,
            'char_start': 5,
            'char_end': 7,
            'sentence_index': 0
          },
          {
            'word': 'the',
            'start_ms': 600,
            'end_ms': 800,
            'char_start': 8,
            'char_end': 11,
            'sentence_index': 0
          },
          {
            'word': 'possibility',
            'start_ms': 800,
            'end_ms': 1400,
            'char_start': 12,
            'char_end': 23,
            'sentence_index': 0
          },
          {
            'word': 'of',
            'start_ms': 1400,
            'end_ms': 1600,
            'char_start': 24,
            'char_end': 26,
            'sentence_index': 0
          },
          {
            'word': 'loss',
            'start_ms': 1600,
            'end_ms': 2000,
            'char_start': 27,
            'char_end': 31,
            'sentence_index': 0
          },
        ],
        'sentence_timings': [
          {
            'text': 'Risk is the possibility of loss.',
            'start_ms': 0,
            'end_ms': 2000,
            'sentence_index': 0,
            'word_start_index': 0,
            'word_end_index': 5,
            'char_start': 0,
            'char_end': 32,
          },
        ],
        'total_duration_ms': 5000,
        'audio_url': 'https://cdn.example.com/audio/lo-001.mp3',
        'audio_size_bytes': 102400,
        'audio_format': 'mp3',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
      };

      final progressJson = {
        'id': 'progress-001',
        'user_id': 'user-001',
        'learning_object_id': 'lo-001',
        'course_id': 'course-001',
        'assignment_id': 'assignment-001',
        'current_position_ms': 1500,
        'last_word_index': 3,
        'last_sentence_index': 0,
        'is_completed': false,
        'playback_speed': 1.25,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
        'last_accessed_at': '2024-01-02T12:00:00Z',
      };

      final settingsJson = {
        'id': 'settings-001',
        'user_id': 'user-001',
        'theme_name': 'dark',
        'theme_settings': {},
        'preferences': {
          'font_size': 18.0,
          'auto_play': true,
          'default_playback_speed': 1.25,
          'word_highlight_color': '#FFEB3B',
          'sentence_highlight_color': '#FFE0B2',
        },
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
      };

      // Parse all models
      final course = Course.fromJson(courseJson);
      final assignment = Assignment.fromJson(assignmentJson);
      final learningObject = LearningObjectV2.fromJson(learningObjectJson);
      final progress = UserProgress.fromJson(progressJson);
      final settings = UserSettings.fromJson(settingsJson);

      // Verify course data
      expect(course.id, equals('course-001'));
      expect(course.courseNumber, equals('INS-101'));
      expect(course.totalLearningObjects, equals(10));
      expect(course.estimatedDuration, equals('1 hr'));

      // Verify assignment data
      expect(assignment.courseId, equals(course.id));
      expect(assignment.assignmentNumber, equals(1));
      expect(assignment.learningObjectCount, equals(3));
      expect(assignment.formattedDuration, equals('20 min'));

      // Verify learning object data
      expect(learningObject.assignmentId, equals(assignment.id));
      expect(learningObject.courseId, equals(course.id));
      expect(learningObject.wordTimings.length, equals(6));
      expect(learningObject.sentenceTimings.length, equals(1));
      expect(learningObject.hasWordTimings, isTrue);
      expect(learningObject.hasSentenceTimings, isTrue);

      // Verify timing continuity
      final wordTimings = learningObject.wordTimings;
      for (int i = 1; i < wordTimings.length; i++) {
        expect(wordTimings[i].startMs, equals(wordTimings[i - 1].endMs),
            reason: 'Word timings should be continuous');
      }

      // Verify progress tracking
      expect(progress.learningObjectId, equals(learningObject.id));
      expect(progress.currentPositionMs, equals(1500));
      expect(progress.lastWordIndex, equals(3));
      expect(progress.getProgressPercentage(learningObject.totalDurationMs),
          equals(30.0)); // 1500/5000 = 30%

      // Verify settings
      expect(settings.getFontSize(), equals(18.0));
      expect(settings.getDefaultPlaybackSpeed(), equals(1.25));
      expect(settings.isDarkMode, isTrue);

      // Simulate playback scenario
      final currentWordIndex = 3; // 'possibility'
      final currentWord = wordTimings[currentWordIndex];
      expect(currentWord.word, equals('possibility'));
      expect(currentWord.sentenceIndex, equals(0));

      // Verify sentence highlight
      final currentSentence = learningObject.sentenceTimings[0];
      expect(
          currentSentence.wordStartIndex, lessThanOrEqualTo(currentWordIndex));
      expect(
          currentSentence.wordEndIndex, greaterThanOrEqualTo(currentWordIndex));

      // Simulate UI update
      final highlightColor = settings.getWordHighlightColor();
      final sentenceHighlightColor = settings.getSentenceHighlightColor();
      expect(highlightColor, equals('#FFEB3B'));
      expect(sentenceHighlightColor, equals('#FFE0B2'));
    });

    test('Handle empty/null JSONB fields gracefully', () {
      // Minimal learning object with empty arrays
      final minimalJson = {
        'id': 'lo-minimal',
        'assignment_id': 'assignment-001',
        'course_id': 'course-001',
        'title': 'Minimal Content',
        'order_index': 0,
        'display_text': 'Simple text.',
        'paragraphs': ['Simple text.'],
        'headers': [],
        'formatting': {},
        'metadata': {
          'word_count': 2,
          'character_count': 12,
          'estimated_reading_time': '1 min',
          'language': 'en',
        },
        'word_timings': [],
        'sentence_timings': [],
        'total_duration_ms': 1000,
        'audio_url': 'https://cdn.example.com/audio.mp3',
        'audio_size_bytes': 1024,
        'audio_format': 'mp3',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      // Should parse without errors
      final learningObject = LearningObjectV2.fromJson(minimalJson);
      expect(learningObject.hasWordTimings, isFalse);
      expect(learningObject.hasSentenceTimings, isFalse);
      expect(learningObject.wordTimings, isEmpty);
      expect(learningObject.sentenceTimings, isEmpty);
    });

    test('User progress updates should maintain consistency', () {
      // Initial progress
      var progress = UserProgress(
        id: 'progress-001',
        userId: 'user-001',
        learningObjectId: 'lo-001',
        courseId: 'course-001',
        assignmentId: 'assignment-001',
        currentPositionMs: 0,
        lastWordIndex: 0,
        lastSentenceIndex: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );

      // Simulate playback updates
      progress = progress.copyWith(
        currentPositionMs: 500,
        lastWordIndex: 1,
      );
      expect(progress.currentPositionMs, equals(500));
      expect(progress.lastWordIndex, equals(1));

      progress = progress.copyWith(
        currentPositionMs: 1500,
        lastWordIndex: 3,
      );
      expect(progress.currentPositionMs, equals(1500));
      expect(progress.lastWordIndex, equals(3));

      // Mark as completed
      progress = progress.copyWith(
        currentPositionMs: 5000,
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      expect(progress.isCompleted, isTrue);
      expect(progress.completedAt, isNotNull);
      expect(progress.getProgressPercentage(5000), equals(100.0));
    });

    test('Settings updates should persist correctly', () {
      var settings = UserSettings(
        id: 'settings-001',
        userId: 'user-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Update font size
      settings = settings.updateFontSize(20.0);
      expect(settings.getFontSize(), equals(20.0));

      // Toggle theme
      settings = settings.toggleTheme();
      expect(settings.isDarkMode, isTrue);

      settings = settings.toggleTheme();
      expect(settings.isDarkMode, isFalse);

      // Update playback speed
      settings = settings.updateDefaultPlaybackSpeed(1.5);
      expect(settings.getDefaultPlaybackSpeed(), equals(1.5));

      // Verify preferences are maintained
      final json = settings.toJson();
      expect(json['preferences']['font_size'], equals(20.0));
      expect(json['preferences']['default_playback_speed'], equals(1.5));
      expect(json['theme_name'], equals('light'));
    });
  });
}
