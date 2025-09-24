/// Service Integration Test
///
/// Purpose: Verify all services compile and work with new database schema
/// This test validates the Phase 4 service updates for DATA_ARCHITECTURE_PLAN

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/course_service.dart';
import 'package:audio_learning_app/services/assignment_service.dart';
import 'package:audio_learning_app/services/learning_object_service.dart';
import 'package:audio_learning_app/services/user_progress_service.dart';
import 'package:audio_learning_app/services/user_settings_service.dart';

void main() {
  group('Service Integration Tests', () {
    test('CourseService should initialize correctly', () {
      validateCourseService();
    });

    test('AssignmentService should initialize correctly', () {
      validateAssignmentService();
    });

    test('LearningObjectService should initialize correctly', () {
      validateLearningObjectService();
    });

    test('UserProgressService should initialize correctly', () {
      validateUserProgressService();
    });

    test('UserSettingsService should initialize correctly', () {
      validateUserSettingsService();
    });

    test('All services should be singletons', () {
      // Course Service
      final courseService1 = CourseService();
      final courseService2 = CourseService();
      expect(identical(courseService1, courseService2), isTrue);

      // Assignment Service
      final assignmentService1 = AssignmentService();
      final assignmentService2 = AssignmentService();
      expect(identical(assignmentService1, assignmentService2), isTrue);

      // Learning Object Service
      final loService1 = LearningObjectService();
      final loService2 = LearningObjectService();
      expect(identical(loService1, loService2), isTrue);

      // User Progress Service
      final progressService1 = UserProgressService();
      final progressService2 = UserProgressService();
      expect(identical(progressService1, progressService2), isTrue);

      // User Settings Service
      final settingsService1 = UserSettingsService();
      final settingsService2 = UserSettingsService();
      expect(identical(settingsService1, settingsService2), isTrue);
    });

    test('Service methods should be properly defined', () {
      final courseService = CourseService();
      final assignmentService = AssignmentService();
      final loService = LearningObjectService();
      final progressService = UserProgressService();
      final settingsService = UserSettingsService();

      // Verify CourseService methods exist
      expect(courseService.fetchAvailableCourses, isNotNull);
      expect(courseService.fetchEnrolledCourses, isNotNull);
      expect(courseService.fetchCourse, isNotNull);
      expect(courseService.enrollInCourse, isNotNull);

      // Verify AssignmentService methods exist
      expect(assignmentService.fetchAssignments, isNotNull);
      expect(assignmentService.fetchAssignment, isNotNull);
      expect(assignmentService.fetchAssignmentsWithProgress, isNotNull);

      // Verify LearningObjectService methods exist
      expect(loService.fetchLearningObjects, isNotNull);
      expect(loService.fetchLearningObject, isNotNull);
      expect(loService.fetchLearningObjectsForCourse, isNotNull);
      expect(loService.fetchLearningObjectsWithProgress, isNotNull);

      // Verify UserProgressService methods exist
      expect(progressService.fetchProgress, isNotNull);
      expect(progressService.updateProgress, isNotNull);
      expect(progressService.markCompleted, isNotNull);
      expect(progressService.fetchCourseStats, isNotNull);
      expect(progressService.fetchAssignmentStats, isNotNull);

      // Verify UserSettingsService methods exist
      expect(settingsService.fetchSettings, isNotNull);
      expect(settingsService.updateFontSize, isNotNull);
      expect(settingsService.updateAutoPlay, isNotNull);
      expect(settingsService.updatePlaybackSpeed, isNotNull);
      expect(settingsService.toggleTheme, isNotNull);
    });
  });
}
