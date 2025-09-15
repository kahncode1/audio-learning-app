/// Mock Data Provider for Audio Learning App
///
/// Purpose: Provides Riverpod state management for mock data, ensuring consistent
/// access patterns and state management across the application.
///
/// External Dependencies:
/// - flutter_riverpod: State management
/// - MockDataService: Mock data generation
/// - Models: Course, Assignment, LearningObject
///
/// Usage Example:
/// ```dart
/// final course = ref.watch(mockCourseProvider);
/// final assignments = ref.watch(mockAssignmentsProvider);
/// final learningObjects = ref.watch(mockLearningObjectsProvider(assignmentId));
/// ```
///
/// Expected Behavior:
/// - Provides cached access to mock data through Riverpod
/// - Maintains consistency with existing provider patterns
/// - Enables easy transition to real data providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../models/assignment.dart';
import '../models/learning_object.dart';
import '../services/mock_data_service.dart';

/// Provider for test course data
final mockCourseProvider = Provider<Course>((ref) {
  return MockDataService.getTestCourse();
});

/// Provider for test assignments
final mockAssignmentsProvider = Provider<List<Assignment>>((ref) {
  return MockDataService.getTestAssignments();
});

/// Provider for test learning objects by assignment ID
final mockLearningObjectsProvider = Provider.family<List<LearningObject>, String>(
  (ref, assignmentId) {
    return MockDataService.getTestLearningObjects(assignmentId);
  },
);

/// Provider for course completion percentage
final mockCourseCompletionProvider = Provider<double>((ref) {
  return MockDataService.getCourseCompletionPercentage();
});

/// Provider for assignment count
final mockAssignmentCountProvider = Provider<int>((ref) {
  return MockDataService.getAssignmentCount();
});

/// Provider for learning object count
final mockLearningObjectCountProvider = Provider<int>((ref) {
  return MockDataService.getLearningObjectCount();
});

/// Validation function for mock data providers
void validateMockDataProviders(WidgetRef ref) {
  print('=== Mock Data Providers Validation ===');

  // Test course provider
  final course = ref.read(mockCourseProvider);
  assert(course.id == 'test-course-001', 'Course provider should return correct ID');
  print('✓ Course provider valid');

  // Test assignments provider
  final assignments = ref.read(mockAssignmentsProvider);
  assert(assignments.length == 3, 'Assignments provider should return 3 items');
  print('✓ Assignments provider valid');

  // Test learning objects provider for different assignments
  final lo1 = ref.read(mockLearningObjectsProvider('test-assignment-001'));
  assert(lo1.length == 2, 'Assignment 1 should have 2 learning objects');
  print('✓ Learning objects provider valid for assignment 1');

  final lo2 = ref.read(mockLearningObjectsProvider('test-assignment-002'));
  assert(lo2.length == 1, 'Assignment 2 should have 1 learning object');
  print('✓ Learning objects provider valid for assignment 2');

  // Test statistic providers
  final completion = ref.read(mockCourseCompletionProvider);
  assert(completion == 25.0, 'Completion should be 25%');
  print('✓ Completion provider valid');

  final assignmentCount = ref.read(mockAssignmentCountProvider);
  assert(assignmentCount == 3, 'Assignment count should be 3');
  print('✓ Assignment count provider valid');

  final loCount = ref.read(mockLearningObjectCountProvider);
  assert(loCount == 4, 'Learning object count should be 4');
  print('✓ Learning object count provider valid');

  print('=== All Mock Data Providers validations passed ===');
}