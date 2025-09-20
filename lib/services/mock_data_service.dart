/// Mock Data Service for Audio Learning App
///
/// Purpose: Provides realistic test data for development and testing of the
/// audio learning application with download-first architecture.
///
/// External Dependencies:
/// - Models: Course, Assignment, LearningObject from models/
/// - No external API dependencies (pure mock data)
///
/// Usage Example:
/// ```dart
/// final course = MockDataService.getTestCourse();
/// final assignments = MockDataService.getTestAssignments();
/// final learningObjects = MockDataService.getTestLearningObjects(assignmentId);
/// ```
///
/// Expected Behavior:
/// - Returns consistent test data for UI development
/// - Provides plain text content for local playback testing
/// - Uses real database ID (63ad7b78-0970-4265-a4fe-51f3fee39d5f) that matches test content files
/// - Provides one test learning object that works with pre-downloaded content
///
/// Note: This service will be replaced with DataService when Supabase integration
/// is complete in Milestone 2.

import '../models/course.dart';
import '../models/assignment.dart';
import '../models/learning_object.dart';

class MockDataService {
  static Course getTestCourse() {
    return Course(
      id: '14350bfb-5e84-4479-b7a2-09ce7a2fdd48', // Real database course ID
      courseNumber: 'INS-101',
      title: 'Insurance Case Management',
      description: 'Test course for development purposes',
      gradientStartColor: '#FF6B6B',
      gradientEndColor: '#C44569',
      totalDurationMs: 3600000,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );
  }

  static List<Assignment> getTestAssignments() {
    return [
      Assignment(
        id: 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', // Real database assignment ID
        courseId: '14350bfb-5e84-4479-b7a2-09ce7a2fdd48', // Real database course ID
        assignmentNumber: 1,
        title: 'Establishing a Case Reserve',
        description: 'Learn how to establish and manage case reserves',
        orderIndex: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Assignment(
        id: 'test-assignment-002',
        courseId: '14350bfb-5e84-4479-b7a2-09ce7a2fdd48', // Real database course ID
        assignmentNumber: 2,
        title: 'Risk Assessment Fundamentals',
        description: 'Understanding basic risk assessment principles',
        orderIndex: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      Assignment(
        id: 'test-assignment-003',
        courseId: '14350bfb-5e84-4479-b7a2-09ce7a2fdd48', // Real database course ID
        assignmentNumber: 3,
        title: 'Claims Documentation',
        description: 'Proper documentation techniques for insurance claims',
        orderIndex: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    ];
  }

  static List<LearningObject> getTestLearningObjects(String assignmentId) {
    if (assignmentId == 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11') { // Real database assignment ID
      // Return test learning object for download-first architecture
      return [
        // Test learning object with pre-downloaded content
        LearningObject(
          id: '63ad7b78-0970-4265-a4fe-51f3fee39d5f', // Real database learning object ID - matches our test content files
          assignmentId: assignmentId,
          title: 'Risk Management and Insurance in Action',
          contentType: 'text',
          // SSML not used in download-first architecture
          ssmlContent: null,
          plainText: '''The objective of this lesson is to illustrate how insurance facilitates key societal activities. This lesson covers the effect of insurance, perception versus reality in the insurance industry, and the evolving role of risk management consulting.''',
          orderIndex: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
        // Test learning object with FIXED timing data (same audio, corrected character positions)
        LearningObject(
          id: 'test-fixed-timing', // Test ID for fixed timing version
          assignmentId: assignmentId,
          title: 'Risk Management (Fixed Timing Test)',
          contentType: 'text',
          ssmlContent: null,
          plainText: '''The objective of this lesson is to illustrate how insurance facilitates key societal activities. This lesson covers the effect of insurance, perception versus reality in the insurance industry, and the evolving role of risk management consulting.''',
          orderIndex: 2,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
        // Test learning object with properly formatted text and aligned character positions
        LearningObject(
          id: 'test-properly-formatted', // Test ID for properly formatted version
          assignmentId: assignmentId,
          title: 'Risk Management (Properly Formatted)',
          contentType: 'text',
          ssmlContent: null,
          plainText: '''The objective of this lesson is to illustrate how insurance facilitates key societal activities. This lesson covers the effect of insurance, perception versus reality in the insurance industry, and the evolving role of risk management consulting.''',
          orderIndex: 3,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
      ];
    } else if (assignmentId == 'test-assignment-002') {
      // Return empty list - no test data for other assignments
      return [];
    } else if (assignmentId == 'test-assignment-003') {
      // Return empty list - no test data for other assignments
      return [];
    }
    return [];
  }

  static int getAssignmentCount() => 3;
  static int getLearningObjectCount() => 3; // Three test learning objects (original + fixed timing + properly formatted)
  static double getCourseCompletionPercentage() => 0.0;

  // Validation function for mock data service
  static void validate() {
    final course = getTestCourse();
    assert(course.courseNumber == 'INS-101');
    assert(course.title == 'Insurance Case Management');

    final assignments = getTestAssignments();
    assert(assignments.length == 3);
    assert(assignments[0].title == 'Establishing a Case Reserve');

    final learningObjects = getTestLearningObjects('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
    assert(learningObjects.length == 3);
    assert(learningObjects[0].title == 'Risk Management and Insurance in Action');
    assert(learningObjects[1].title == 'Risk Management (Fixed Timing Test)');
    assert(learningObjects[2].title == 'Risk Management (Properly Formatted)');

    // Verify no learning objects for other assignments
    final lo2 = getTestLearningObjects('test-assignment-002');
    assert(lo2.isEmpty);

    final lo3 = getTestLearningObjects('test-assignment-003');
    assert(lo3.isEmpty);

    print('✓ MockDataService validation passed');
  }
}
