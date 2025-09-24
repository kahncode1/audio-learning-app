import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/models.dart';

/// Tests for the models barrel export file
///
/// Purpose: Ensures all models are properly exported from models.dart
/// This replaces the outdated models_test.dart with modern APIs
void main() {
  group('Models Export', () {
    test('should export all core model classes', () {
      // Test that all classes are accessible through the barrel export
      expect(() => User, returnsNormally);
      expect(() => Course, returnsNormally);
      expect(() => Assignment, returnsNormally);
      expect(() => LearningObject, returnsNormally);
      expect(() => LearningObjectV2, returnsNormally);
      expect(() => WordTiming, returnsNormally);
      expect(() => SentenceTiming, returnsNormally);
      expect(() => ProgressState, returnsNormally);
      expect(() => EnrolledCourse, returnsNormally);
      expect(() => ContentMetadata, returnsNormally);
      expect(() => UserProgress, returnsNormally);
      expect(() => UserSettings, returnsNormally);
    });

    test('should allow instantiation of core models with minimal constructor', () {
      final now = DateTime.now();

      // Test basic constructors work (detailed tests are in individual model test files)
      expect(
        () => User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          createdAt: now,
          updatedAt: now
        ),
        returnsNormally,
      );

      expect(
        () => Course(
          id: 'test',
          courseNumber: 'TEST-101',
          title: 'Test',
          createdAt: now,
          updatedAt: now
        ),
        returnsNormally,
      );

      expect(
        () => Assignment(
          id: 'test',
          courseId: 'course',
          assignmentNumber: 1,
          title: 'Test',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now
        ),
        returnsNormally,
      );
    });
  });
}