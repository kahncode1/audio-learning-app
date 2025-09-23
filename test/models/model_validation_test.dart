/// Model Validation Test
///
/// Purpose: Verify all updated models compile and work correctly
/// This test validates the Phase 3 model updates for DATA_ARCHITECTURE_PLAN

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/course.dart';
import 'package:audio_learning_app/models/assignment.dart';
import 'package:audio_learning_app/models/learning_object_v2.dart';
import 'package:audio_learning_app/models/word_timing.dart';
import 'package:audio_learning_app/models/sentence_timing.dart';
import 'package:audio_learning_app/models/content_metadata.dart';
import 'package:audio_learning_app/models/user_progress.dart';
import 'package:audio_learning_app/models/user_settings.dart';

void main() {
  group('Model Validation Tests', () {
    test('Course model should parse and serialize correctly', () {
      validateCourseModel();
    });

    test('Assignment model should parse and serialize correctly', () {
      validateAssignmentModel();
    });

    test('LearningObjectV2 model should parse and serialize correctly', () {
      validateLearningObjectV2Model();
    });

    test('WordTiming model should parse and serialize correctly', () {
      validateWordTimingModel();
    });

    test('SentenceTiming model should parse and serialize correctly', () {
      validateSentenceTimingModel();
    });

    test('UserProgress model should parse and serialize correctly', () {
      validateUserProgressModel();
    });

    test('UserSettings model should parse and serialize correctly', () {
      validateUserSettingsModel();
    });

    test('All models should work together', () {
      // Create a complete data structure
      final course = Course(
        id: 'course-1',
        courseNumber: 'INS-101',
        title: 'Insurance Fundamentals',
        totalLearningObjects: 10,
        totalAssignments: 3,
        estimatedDurationMs: 3600000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final assignment = Assignment(
        id: 'assignment-1',
        courseId: course.id,
        assignmentNumber: 1,
        title: 'Introduction',
        learningObjectCount: 3,
        totalDurationMs: 1200000,
        orderIndex: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final learningObject = LearningObjectV2(
        id: 'lo-1',
        assignmentId: assignment.id,
        courseId: course.id,
        title: 'Lesson 1',
        orderIndex: 0,
        displayText: 'Test content',
        paragraphs: ['Test content'],
        headers: [],
        formatting: ContentFormatting(),
        metadata: ContentMetadata(
          wordCount: 2,
          characterCount: 12,
          estimatedReadingTime: '1 min',
          language: 'en',
        ),
        wordTimings: [
          WordTiming(
            word: 'Test',
            startMs: 0,
            endMs: 500,
            sentenceIndex: 0,
          ),
          WordTiming(
            word: 'content',
            startMs: 500,
            endMs: 1000,
            sentenceIndex: 0,
          ),
        ],
        sentenceTimings: [
          SentenceTiming(
            text: 'Test content',
            startMs: 0,
            endMs: 1000,
            sentenceIndex: 0,
            wordStartIndex: 0,
            wordEndIndex: 1,
            charStart: 0,
            charEnd: 12,
          ),
        ],
        totalDurationMs: 1000,
        audioUrl: 'https://example.com/audio.mp3',
        audioSizeBytes: 1024,
        audioFormat: 'mp3',
        fileVersion: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final progress = UserProgress(
        id: 'progress-1',
        userId: 'user-1',
        learningObjectId: learningObject.id,
        courseId: course.id,
        assignmentId: assignment.id,
        currentPositionMs: 500,
        lastWordIndex: 0,
        lastSentenceIndex: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );

      final settings = UserSettings(
        id: 'settings-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify relationships
      expect(assignment.courseId, equals(course.id));
      expect(learningObject.assignmentId, equals(assignment.id));
      expect(learningObject.courseId, equals(course.id));
      expect(progress.learningObjectId, equals(learningObject.id));
      expect(progress.courseId, equals(course.id));
      expect(progress.assignmentId, equals(assignment.id));

      // Verify computed properties
      expect(course.estimatedDuration, equals('1 hr'));
      expect(assignment.formattedDuration, equals('20 min'));
      expect(learningObject.hasWordTimings, isTrue);
      expect(learningObject.hasSentenceTimings, isTrue);
      expect(progress.hasStarted, isTrue);
      expect(progress.getProgressPercentage(1000), equals(50.0));
      expect(settings.getFontSize(), equals(16.0));
      expect(settings.isDarkMode, isFalse);
    });
  });
}