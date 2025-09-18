/// Mock Data Service for Audio Learning App
///
/// Purpose: Provides realistic test data for development and testing of the
/// audio learning application. This service simulates the data structure that
/// will be provided by Supabase in production.
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
/// - Provides SSML content for TTS testing
/// - Uses real database ID (63ad7b78-0970-4265-a4fe-51f3fee39d5f) for seamless integration
/// - Provides only one test learning object for the first assignment
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
      // Return test learning objects for development
      return [
        // ElevenLabs Test Version - Plain text only
        LearningObject(
          id: 'elevenlabs-test-001',
          assignmentId: assignmentId,
          title: 'ElevenLabs Test - Case Reserve Management',
          contentType: 'text',
          // No SSML content - force use of plainText for ElevenLabs
          ssmlContent: null,
          plainText: '''Understanding Case Reserve Management in Insurance Claims Processing. A case reserve represents the estimated amount of money an insurance company expects to pay for a claim. This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting. When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure. This initial evaluation becomes the foundation for the case reserve. The reserve amount includes not only the expected indemnity payment to the claimant but also allocated loss adjustment expenses, legal fees, and expert witness costs that may arise during the claims process. Insurance companies rely on accurate case reserves for several vital business functions. First, reserves directly impact the company's financial statements and must be reported to regulators and shareholders. Second, they influence reinsurance recoveries and treaty arrangements. Third, accurate reserves enable better pricing decisions for future policies. Finally, they provide management with crucial data for strategic planning and capital allocation decisions. Every case reserve should incorporate multiple elements to ensure accuracy and completeness. The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf. This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases. Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses. These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees. Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle. The timing of payments also affects reserve calculations. A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation. Claims professionals must consider the time value of money, especially for claims that may take years to resolve. Establishing accurate initial reserves requires a systematic approach combined with professional judgment. The process begins with a thorough investigation of the claim circumstances, including witness statements, police reports, medical records, and any available surveillance footage. This information provides the factual foundation for the reserve evaluation. Documentation is crucial when setting initial reserves. Adjusters should clearly record their reasoning, the factors considered, and any assumptions made. This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters. Case reserves are not static figures. They require regular review and adjustment as new information emerges and circumstances change. Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim's complexity and value. Thank you for completing this lesson on case reserve management. Remember that effective reserve management remains fundamental to successful claims operations.''',
          orderIndex: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ),
        // Original SSML version for Speechify
        LearningObject(
          id: '63ad7b78-0970-4265-a4fe-51f3fee39d5f', // Real database learning object ID
          assignmentId: assignmentId,
          title: 'Establishing a Case Reserve - Full Lesson (Speechify)',
          contentType: 'text',
          // SSML explicitly structured with paragraphs (<p>) and sentences (<s>)
          // to ensure stable sentence chunking and accurate timing.
          ssmlContent: '''<speak>
  <p>
    <s>Welcome to the lesson on establishing case reserves.</s>
    <s>A case reserve is an estimate of the amount of money that will be needed to settle a claim.</s>
    <s>Setting accurate reserves is critical for managing insurance company finances.</s>
  </p>
  <p>
    <s>Reserves must be reviewed regularly to ensure they remain appropriate as claims develop.</s>
    <s>The initial reserve is often set based on limited information and must be adjusted as more facts become available.</s>
  </p>
  <p>
    <s>Factors to consider include medical costs, lost wages, property damage, and potential legal expenses.</s>
    <s>Experienced adjusters use historical data and industry benchmarks to guide their reserve decisions.</s>
  </p>
  <p>
    <s>Documentation is essential — every reserve change must be justified and recorded in the claim file.</s>
    <s>Regular reserve adequacy reviews help identify trends and improve future reserving accuracy.</s>
  </p>
  <p>
    <s>Thank you for completing this comprehensive lesson on case reserve management.</s>
  </p>
</speak>''',
          plainText: '''Welcome to the lesson on establishing case reserves. A case reserve is an estimate of the amount of money that will be needed to settle a claim. Setting accurate reserves is critical for managing insurance company finances. Reserves must be reviewed regularly to ensure they remain appropriate as claims develop. The initial reserve is often set based on limited information and must be adjusted as more facts become available. Factors to consider include medical costs, lost wages, property damage, and potential legal expenses. Experienced adjusters use historical data and industry benchmarks to guide their reserve decisions. Documentation is essential - every reserve change must be justified and recorded in the claim file. Regular reserve adequacy reviews help identify trends and improve future reserving accuracy. Thank you for completing this comprehensive lesson on case reserve management.''',
          orderIndex: 1,
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
  static int getLearningObjectCount() => 2; // Two test learning objects now (ElevenLabs + Speechify)
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
    assert(learningObjects.length == 2);
    assert(learningObjects[0].title == 'ElevenLabs Test - Case Reserve Management');
    assert(learningObjects[1].title == 'Establishing a Case Reserve - Full Lesson (Speechify)');

    // Verify no learning objects for other assignments
    final lo2 = getTestLearningObjects('test-assignment-002');
    assert(lo2.isEmpty);

    final lo3 = getTestLearningObjects('test-assignment-003');
    assert(lo3.isEmpty);

    print('✓ MockDataService validation passed');
  }
}
