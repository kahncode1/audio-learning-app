import '../models/course.dart';
import '../models/assignment.dart';
import '../models/learning_object.dart';

class MockDataService {
  static Course getTestCourse() {
    return Course(
      id: 'test-course-001',
      courseNumber: 'INS-101',
      title: 'Insurance Case Management (Test)',
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
        id: 'test-assignment-001',
        courseId: 'test-course-001',
        assignmentNumber: 1,
        title: 'Establishing a Case Reserve',
        description: 'Learn how to establish and manage case reserves',
        orderIndex: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Assignment(
        id: 'test-assignment-002',
        courseId: 'test-course-001',
        assignmentNumber: 2,
        title: 'Risk Assessment Fundamentals',
        description: 'Understanding basic risk assessment principles',
        orderIndex: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      Assignment(
        id: 'test-assignment-003',
        courseId: 'test-course-001',
        assignmentNumber: 3,
        title: 'Claims Documentation',
        description: 'Proper documentation techniques for insurance claims',
        orderIndex: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    ];
  }

  static List<LearningObject> getTestLearningObjects(String assignmentId) {
    if (assignmentId == 'test-assignment-001') {
      return [
        LearningObject(
          id: '94096d75-7125-49be-b11c-49a9d5b5660d', // Real DB ID for testing
          assignmentId: assignmentId,
          title: 'Introduction to Case Reserves',
          contentType: 'text',
          ssmlContent: '''
<speak>
<p>Welcome to the lesson on establishing case reserves.</p>
<p>A case reserve is an estimate of the amount of money that will be needed to settle a claim.</p>
<p>Setting accurate reserves is critical for managing insurance company finances and ensuring adequate funds are available when claims need to be paid.</p>
<p>In this lesson, we'll cover the key factors to consider when establishing a reserve, common methods used in the industry, and best practices for maintaining reserve accuracy over time.</p>
</speak>''',
          plainText: 'Welcome to the lesson on establishing case reserves...',
          orderIndex: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
        LearningObject(
          id: 'test-lo-002',
          assignmentId: assignmentId,
          title: 'Factors in Reserve Calculation',
          contentType: 'text',
          ssmlContent: '''
<speak>
<p>When calculating case reserves, several factors must be considered.</p>
<p>These include the severity of the injury, expected medical costs, potential legal fees, and historical claim data.</p>
</speak>''',
          plainText: 'When calculating case reserves, several factors must be considered...',
          orderIndex: 2,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
      ];
    } else if (assignmentId == 'test-assignment-002') {
      return [
        LearningObject(
          id: 'test-lo-003',
          assignmentId: assignmentId,
          title: 'Understanding Risk Categories',
          contentType: 'text',
          ssmlContent: '''
<speak>
<p>Risk assessment begins with understanding different risk categories.</p>
<p>We'll explore physical risks, financial risks, and operational risks in detail.</p>
</speak>''',
          plainText: 'Risk assessment begins with understanding different risk categories...',
          orderIndex: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 25)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
      ];
    } else if (assignmentId == 'test-assignment-003') {
      return [
        LearningObject(
          id: 'test-lo-004',
          assignmentId: assignmentId,
          title: 'Documentation Best Practices',
          contentType: 'text',
          ssmlContent: '''
<speak>
<p>Proper documentation is essential for successful claims processing.</p>
<p>Learn the key elements that must be included in every claim file.</p>
</speak>''',
          plainText: 'Proper documentation is essential for successful claims processing...',
          orderIndex: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
      ];
    }
    return [];
  }

  static int getAssignmentCount() => 3;

  static int getLearningObjectCount() => 4;

  static double getCourseCompletionPercentage() => 25.0; // Simulating 25% completion
}