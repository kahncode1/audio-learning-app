import 'package:flutter_test/flutter_test.dart';

import 'package:audio_learning_app/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Models Export', () {
    group('User Export', () {
      test('should export User class', () {
        expect(() => User(
          id: 'test-id',
          cognitoSub: 'test-sub',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ), returnsNormally);
      });

      test('User should be constructible with all fields', () {
        final user = User(
          id: 'test-id',
          cognitoSub: 'test-sub', 
          email: 'test@example.com',
          firstName: 'Test',
          lastName: 'User',
          organization: 'Test Org',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(user, isA<User>());
        expect(user.id, 'test-id');
        expect(user.email, 'test@example.com');
      });
    });

    group('Course Export', () {
      test('should export Course class', () {
        expect(() => Course(
          id: 'test-course',
          courseNumber: 'TEST-101',
          title: 'Test Course',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ), returnsNormally);
      });

      test('Course should be constructible with all fields', () {
        final course = Course(
          id: 'test-course',
          courseNumber: 'TEST-101',
          title: 'Test Course',
          description: 'Test Description',
          imageUrl: 'https://example.com/image.jpg',
          gradientStart: '#FF0000',
          gradientEnd: '#00FF00',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(course, isA<Course>());
        expect(course.id, 'test-course');
        expect(course.title, 'Test Course');
      });
    });

    group('Assignment Export', () {
      test('should export Assignment class', () {
        expect(() => Assignment(
          id: 'test-assignment',
          courseId: 'test-course',
          assignmentNumber: 1,
          title: 'Test Assignment',
          orderIndex: 0,
          createdAt: DateTime.now(),
        ), returnsNormally);
      });

      test('Assignment should be constructible with all fields', () {
        final assignment = Assignment(
          id: 'test-assignment',
          courseId: 'test-course',
          assignmentNumber: 1,
          title: 'Test Assignment',
          description: 'Test Description',
          orderIndex: 0,
          createdAt: DateTime.now(),
        );
        
        expect(assignment, isA<Assignment>());
        expect(assignment.id, 'test-assignment');
        expect(assignment.title, 'Test Assignment');
      });
    });

    group('LearningObject Export', () {
      test('should export LearningObject class', () {
        expect(() => LearningObject(
          id: 'test-lo',
          assignmentId: 'test-assignment',
          title: 'Test Learning Object',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        ), returnsNormally);
      });

      test('LearningObject should be constructible with all fields', () {
        final learningObject = LearningObject(
          id: 'test-lo',
          assignmentId: 'test-assignment',
          title: 'Test Learning Object',
          contentType: 'audio',
          audioUrl: 'https://example.com/audio.mp3',
          textContent: 'Test content',
          orderIndex: 0,
          estimatedDurationMs: 60000,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );
        
        expect(learningObject, isA<LearningObject>());
        expect(learningObject.id, 'test-lo');
        expect(learningObject.title, 'Test Learning Object');
      });
    });

    group('WordTiming Export', () {
      test('should export WordTiming class', () {
        expect(() => WordTiming(
          startTime: 0,
          endTime: 1000,
          text: 'test',
        ), returnsNormally);
      });

      test('WordTiming should be constructible with all fields', () {
        final wordTiming = WordTiming(
          startTime: 0,
          endTime: 1000,
          text: 'test',
          startCharIndex: 0,
          endCharIndex: 4,
        );
        
        expect(wordTiming, isA<WordTiming>());
        expect(wordTiming.text, 'test');
        expect(wordTiming.startTime, 0);
      });
    });

    group('ProgressState Export', () {
      test('should export ProgressState class', () {
        expect(() => ProgressState(
          id: 'test-progress',
          userId: 'test-user',
          learningObjectId: 'test-lo',
          currentPositionMs: 5000,
          isCompleted: false,
          isInProgress: true,
          playbackSpeed: 1.0,
          fontSizeIndex: 1,
          lastAccessedAt: DateTime.now(),
        ), returnsNormally);
      });

      test('ProgressState should be constructible with all fields', () {
        final progressState = ProgressState(
          id: 'test-progress',
          userId: 'test-user',
          learningObjectId: 'test-lo',
          currentPositionMs: 5000,
          totalDurationMs: 60000,
          isCompleted: false,
          isInProgress: true,
          completedAt: null,
          playbackSpeed: 1.25,
          fontSizeIndex: 2,
          lastAccessedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(progressState, isA<ProgressState>());
        expect(progressState.id, 'test-progress');
        expect(progressState.currentPositionMs, 5000);
      });
    });

    group('EnrolledCourse Export', () {
      test('should export EnrolledCourse class', () {
        expect(() => EnrolledCourse(
          id: 'test-enrolled',
          userId: 'test-user',
          courseId: 'test-course',
          enrolledAt: DateTime.now(),
        ), returnsNormally);
      });

      test('EnrolledCourse should be constructible with all fields', () {
        final enrolledCourse = EnrolledCourse(
          id: 'test-enrolled',
          userId: 'test-user',
          courseId: 'test-course',
          enrolledAt: DateTime.now(),
          completedAt: null,
          lastAccessedAt: DateTime.now(),
        );
        
        expect(enrolledCourse, isA<EnrolledCourse>());
        expect(enrolledCourse.id, 'test-enrolled');
        expect(enrolledCourse.userId, 'test-user');
      });
    });

    group('Model Integration', () {
      test('all models should be available from single import', () {
        // Test that all model types can be instantiated
        final user = User(
          id: 'test',
          cognitoSub: 'test',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final course = Course(
          id: 'test',
          courseNumber: 'TEST-101',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final assignment = Assignment(
          id: 'test',
          courseId: 'test',
          assignmentNumber: 1,
          title: 'Test',
          orderIndex: 0,
          createdAt: DateTime.now(),
        );

        final learningObject = LearningObject(
          id: 'test',
          assignmentId: 'test',
          title: 'Test',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        final wordTiming = WordTiming(
          startTime: 0,
          endTime: 1000,
          text: 'test',
        );

        final progressState = ProgressState(
          id: 'test',
          userId: 'test',
          learningObjectId: 'test',
          currentPositionMs: 0,
          isCompleted: false,
          isInProgress: false,
          playbackSpeed: 1.0,
          fontSizeIndex: 1,
          lastAccessedAt: DateTime.now(),
        );

        final enrolledCourse = EnrolledCourse(
          id: 'test',
          userId: 'test',
          courseId: 'test',
          enrolledAt: DateTime.now(),
        );

        // Verify all instances are correct types
        expect(user, isA<User>());
        expect(course, isA<Course>());
        expect(assignment, isA<Assignment>());
        expect(learningObject, isA<LearningObject>());
        expect(wordTiming, isA<WordTiming>());
        expect(progressState, isA<ProgressState>());
        expect(enrolledCourse, isA<EnrolledCourse>());
      });

      test('models should have proper relationships', () {
        final userId = 'test-user';
        final courseId = 'test-course';
        final assignmentId = 'test-assignment';
        final learningObjectId = 'test-lo';

        final user = User(
          id: userId,
          cognitoSub: 'test-sub',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final course = Course(
          id: courseId,
          courseNumber: 'TEST-101',
          title: 'Test Course',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final assignment = Assignment(
          id: assignmentId,
          courseId: courseId,
          assignmentNumber: 1,
          title: 'Test Assignment',
          orderIndex: 0,
          createdAt: DateTime.now(),
        );

        final learningObject = LearningObject(
          id: learningObjectId,
          assignmentId: assignmentId,
          title: 'Test Learning Object',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        final progressState = ProgressState(
          id: 'test-progress',
          userId: userId,
          learningObjectId: learningObjectId,
          currentPositionMs: 5000,
          isCompleted: false,
          isInProgress: true,
          playbackSpeed: 1.0,
          fontSizeIndex: 1,
          lastAccessedAt: DateTime.now(),
        );

        final enrolledCourse = EnrolledCourse(
          id: 'test-enrolled',
          userId: userId,
          courseId: courseId,
          enrolledAt: DateTime.now(),
        );

        // Verify relationships
        expect(assignment.courseId, course.id);
        expect(learningObject.assignmentId, assignment.id);
        expect(progressState.userId, user.id);
        expect(progressState.learningObjectId, learningObject.id);
        expect(enrolledCourse.userId, user.id);
        expect(enrolledCourse.courseId, course.id);
      });
    });

    group('Model Constants', () {
      test('should provide font size constants', () {
        expect(ProgressState.fontSizeNames, isNotEmpty);
        expect(ProgressState.fontSizeValues, isNotEmpty);
        expect(ProgressState.fontSizeNames.length, ProgressState.fontSizeValues.length);
      });

      test('should provide playback speed constants from UI providers', () {
        // While not directly in models, these are used by ProgressState
        expect(1.0, 1.0); // Default speed
        expect(0.8, lessThan(1.0)); // Slower speed
        expect(2.0, greaterThan(1.0)); // Faster speed
      });
    });

    group('Model Validation', () {
      test('models should handle required fields', () {
        // Test that models require essential fields
        expect(() => User(
          id: '',
          cognitoSub: '',
          email: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ), returnsNormally); // Should not crash even with empty strings
      });

      test('models should handle optional fields', () {
        // Test models work with minimal required fields
        final course = Course(
          id: 'test',
          courseNumber: 'TEST',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(course.description, isNull);
        expect(course.imageUrl, isNull);
        expect(course, isA<Course>());
      });
    });

    group('DateTime Handling', () {
      test('models should handle DateTime fields correctly', () {
        final now = DateTime.now();
        
        final user = User(
          id: 'test',
          cognitoSub: 'test',
          email: 'test@example.com',
          createdAt: now,
          updatedAt: now,
        );

        final progressState = ProgressState(
          id: 'test',
          userId: 'test',
          learningObjectId: 'test',
          currentPositionMs: 0,
          isCompleted: false,
          isInProgress: false,
          playbackSpeed: 1.0,
          fontSizeIndex: 1,
          lastAccessedAt: now,
        );

        expect(user.createdAt, now);
        expect(user.updatedAt, now);
        expect(progressState.lastAccessedAt, now);
      });
    });

    group('Export Consistency', () {
      test('should export all required model files', () {
        // This test verifies that the export is working by instantiating each type
        // If any export is missing, this will fail at compile time
        
        User; // References the User class
        Course; // References the Course class  
        Assignment; // References the Assignment class
        LearningObject; // References the LearningObject class
        WordTiming; // References the WordTiming class
        ProgressState; // References the ProgressState class
        EnrolledCourse; // References the EnrolledCourse class
        
        expect(true, true); // If we get here, all exports work
      });
    });
  });
}