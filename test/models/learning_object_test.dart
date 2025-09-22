import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/learning_object.dart';

void main() {
  group('LearningObject Model', () {
    final testJson = {
      'id': 'learning-456',
      'assignment_id': 'assign-123',
      'title': 'Introduction to Risk Assessment',
      'content_type': 'audio',
      'ssml_content': '<speak>This is SSML content.</speak>',
      'plain_text': 'This is plain text content.',
      'order_index': 1,
      'created_at': '2024-03-10T14:30:00Z',
      'updated_at': '2024-03-15T10:15:00Z',
      'is_completed': true,
      'current_position_ms': 30000,
    };

    group('Constructor', () {
      test('should create LearningObject with all required fields', () {
        final learningObject = LearningObject(
          id: 'test-id',
          assignmentId: 'assign-id',
          title: 'Test Learning Object',
          contentType: 'text',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        expect(learningObject.id, 'test-id');
        expect(learningObject.assignmentId, 'assign-id');
        expect(learningObject.title, 'Test Learning Object');
        expect(learningObject.contentType, 'text');
        expect(learningObject.ssmlContent, isNull);
        expect(learningObject.plainText, isNull);
        expect(learningObject.orderIndex, 0);
        expect(learningObject.isCompleted, false);
        expect(learningObject.currentPositionMs, 0);
      });

      test('should create LearningObject with optional fields', () {
        final now = DateTime.now();
        final learningObject = LearningObject(
          id: 'test-id',
          assignmentId: 'assign-id',
          title: 'Test Learning Object',
          contentType: 'audio',
          ssmlContent: '<speak>SSML</speak>',
          plainText: 'Plain text',
          orderIndex: 2,
          createdAt: now,
          updatedAt: now,
          isCompleted: true,
          currentPositionMs: 15000,
        );

        expect(learningObject.ssmlContent, '<speak>SSML</speak>');
        expect(learningObject.plainText, 'Plain text');
        expect(learningObject.isCompleted, true);
        expect(learningObject.currentPositionMs, 15000);
      });
    });

    group('JSON Serialization', () {
      test('fromJson should parse valid JSON correctly', () {
        final learningObject = LearningObject.fromJson(testJson);

        expect(learningObject.id, 'learning-456');
        expect(learningObject.assignmentId, 'assign-123');
        expect(learningObject.title, 'Introduction to Risk Assessment');
        expect(learningObject.contentType, 'audio');
        expect(learningObject.ssmlContent, '<speak>This is SSML content.</speak>');
        expect(learningObject.plainText, 'This is plain text content.');
        expect(learningObject.orderIndex, 1);
        expect(learningObject.createdAt, DateTime.parse('2024-03-10T14:30:00Z'));
        expect(learningObject.updatedAt, DateTime.parse('2024-03-15T10:15:00Z'));
        expect(learningObject.isCompleted, true);
        expect(learningObject.currentPositionMs, 30000);
      });

      test('fromJson should handle null optional fields', () {
        final minimalJson = {
          'id': 'minimal-id',
          'assignment_id': 'assign-minimal',
          'title': 'Minimal Learning Object',
          'content_type': 'text',
          'order_index': 0,
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
          'is_completed': false,
          'current_position_ms': 0,
        };

        final learningObject = LearningObject.fromJson(minimalJson);

        expect(learningObject.ssmlContent, isNull);
        expect(learningObject.plainText, isNull);
        expect(learningObject.isCompleted, false);
        expect(learningObject.currentPositionMs, 0);
      });

      test('toJson should serialize all fields correctly', () {
        final learningObject = LearningObject.fromJson(testJson);
        final json = learningObject.toJson();

        expect(json['id'], 'learning-456');
        expect(json['assignment_id'], 'assign-123');
        expect(json['title'], 'Introduction to Risk Assessment');
        expect(json['content_type'], 'audio');
        expect(json['ssml_content'], '<speak>This is SSML content.</speak>');
        expect(json['plain_text'], 'This is plain text content.');
        expect(json['order_index'], 1);
        expect(json['created_at'], '2024-03-10T14:30:00.000Z');
        expect(json['updated_at'], '2024-03-15T10:15:00.000Z');
        expect(json['is_completed'], true);
        expect(json['current_position_ms'], 30000);
      });

      test('round-trip serialization should preserve data', () {
        final original = LearningObject.fromJson(testJson);
        final json = original.toJson();
        final restored = LearningObject.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.assignmentId, original.assignmentId);
        expect(restored.title, original.title);
        expect(restored.contentType, original.contentType);
        expect(restored.ssmlContent, original.ssmlContent);
        expect(restored.plainText, original.plainText);
        expect(restored.orderIndex, original.orderIndex);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
        expect(restored.isCompleted, original.isCompleted);
        expect(restored.currentPositionMs, original.currentPositionMs);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = LearningObject.fromJson(testJson);
        final updated = original.copyWith(
          title: 'Updated Title',
          isCompleted: false,
          currentPositionMs: 45000,
        );

        expect(updated.id, original.id);
        expect(updated.assignmentId, original.assignmentId);
        expect(updated.title, 'Updated Title');
        expect(updated.isCompleted, false);
        expect(updated.currentPositionMs, 45000);
        expect(updated.contentType, original.contentType);
        expect(updated.ssmlContent, original.ssmlContent);
      });

      test('should preserve original when no fields changed', () {
        final original = LearningObject.fromJson(testJson);
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.title, original.title);
        expect(copy.isCompleted, original.isCompleted);
        expect(copy.currentPositionMs, original.currentPositionMs);
      });

      test('should allow clearing nullable fields', () {
        final original = LearningObject(
          id: 'test',
          assignmentId: 'assign',
          title: 'Test',
          contentType: 'audio',
          ssmlContent: '<speak>Has SSML</speak>',
          plainText: 'Has plain text',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        final updated = original.copyWith(
          ssmlContent: null,
          plainText: null,
        );

        expect(updated.ssmlContent, isNull);
        expect(updated.plainText, isNull);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final now = DateTime.now();
        final learningObject1 = LearningObject(
          id: 'same-id',
          assignmentId: 'assign-1',
          title: 'Object 1',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
          isCompleted: false,
          currentPositionMs: 0,
        );

        final learningObject2 = LearningObject(
          id: 'same-id',
          assignmentId: 'assign-2',
          title: 'Object 2',
          contentType: 'text',
          orderIndex: 1,
          createdAt: now.add(const Duration(days: 1)),
          updatedAt: now.add(const Duration(days: 1)),
          isCompleted: true,
          currentPositionMs: 1000,
        );

        expect(learningObject1, equals(learningObject2));
        expect(learningObject1.hashCode, learningObject2.hashCode);
      });

      test('should not be equal when IDs differ', () {
        final now = DateTime.now();
        final learningObject1 = LearningObject(
          id: 'id-1',
          assignmentId: 'same-assign',
          title: 'Same Title',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
          isCompleted: false,
          currentPositionMs: 0,
        );

        final learningObject2 = LearningObject(
          id: 'id-2',
          assignmentId: 'same-assign',
          title: 'Same Title',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
          isCompleted: false,
          currentPositionMs: 0,
        );

        expect(learningObject1, isNot(equals(learningObject2)));
      });

      test('should be equal to itself', () {
        final learningObject = LearningObject.fromJson(testJson);
        expect(learningObject, equals(learningObject));
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final learningObject = LearningObject(
          id: 'test-123',
          assignmentId: 'assign-456',
          title: 'Test Learning Object',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        final str = learningObject.toString();
        expect(str, contains('test-123'));
        expect(str, contains('Test Learning Object'));
      });
    });

    group('Progress Tracking', () {
      test('should track completion status', () {
        final learningObject = LearningObject(
          id: 'test',
          assignmentId: 'assign',
          title: 'Test',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: true,
          currentPositionMs: 60000,
        );

        expect(learningObject.isCompleted, true);
        expect(learningObject.currentPositionMs, 60000);
      });

      test('should handle position in milliseconds', () {
        final learningObject = LearningObject(
          id: 'test',
          assignmentId: 'assign',
          title: 'Test',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 123456,
        );

        expect(learningObject.currentPositionMs, 123456);
        
        // Calculate progress percentage (example)
        const totalDurationMs = 300000; // 5 minutes
        final progressPercent = (learningObject.currentPositionMs / totalDurationMs * 100).round();
        expect(progressPercent, 41);
      });
    });

    group('Content Types', () {
      test('should support different content types', () {
        final audioObject = LearningObject(
          id: 'audio-1',
          assignmentId: 'assign',
          title: 'Audio Content',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        final textObject = LearningObject(
          id: 'text-1',
          assignmentId: 'assign',
          title: 'Text Content',
          contentType: 'text',
          orderIndex: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        expect(audioObject.contentType, 'audio');
        expect(textObject.contentType, 'text');
      });
    });

    group('SSML and Plain Text', () {
      test('can have both SSML and plain text', () {
        final learningObject = LearningObject(
          id: 'test',
          assignmentId: 'assign',
          title: 'Test',
          contentType: 'audio',
          ssmlContent: '<speak>SSML version</speak>',
          plainText: 'Plain text version',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        expect(learningObject.ssmlContent, isNotNull);
        expect(learningObject.plainText, isNotNull);
      });

      test('can have only SSML content', () {
        final learningObject = LearningObject(
          id: 'test',
          assignmentId: 'assign',
          title: 'Test',
          contentType: 'audio',
          ssmlContent: '<speak>Only SSML</speak>',
          plainText: null,
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        expect(learningObject.ssmlContent, isNotNull);
        expect(learningObject.plainText, isNull);
      });

      test('can have only plain text content', () {
        final learningObject = LearningObject(
          id: 'test',
          assignmentId: 'assign',
          title: 'Test',
          contentType: 'text',
          ssmlContent: null,
          plainText: 'Only plain text',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        expect(learningObject.ssmlContent, isNull);
        expect(learningObject.plainText, isNotNull);
      });
    });

    group('Validation Function', () {
      test('validateLearningObjectModel should not throw', () {
        expect(() => validateLearningObjectModel(), returnsNormally);
      });
    });
  });
}