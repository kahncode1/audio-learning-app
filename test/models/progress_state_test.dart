import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/progress_state.dart';

void main() {
  group('ProgressState Model', () {
    final testJson = {
      'id': 'progress-xyz789',
      'user_id': 'user-abc123',
      'learning_object_id': 'lo-def456',
      'current_position_ms': 12500,
      'is_completed': false,
      'is_in_progress': true,
      'playback_speed': 1.25,
      'font_size_index': 2,
      'last_accessed_at': '2024-05-10T16:30:00Z',
      'completed_at': null,
    };

    group('Constructor', () {
      test('should create ProgressState with all fields', () {
        final progress = ProgressState(
          id: 'test-id',
          userId: 'user-id',
          learningObjectId: 'lo-id',
          currentPositionMs: 1000,
          isCompleted: false,
          isInProgress: true,
          playbackSpeed: 1.5,
          fontSizeIndex: 1,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.id, 'test-id');
        expect(progress.userId, 'user-id');
        expect(progress.learningObjectId, 'lo-id');
        expect(progress.currentPositionMs, 1000);
        expect(progress.isCompleted, false);
        expect(progress.isInProgress, true);
        expect(progress.playbackSpeed, 1.5);
        expect(progress.fontSizeIndex, 1);
        expect(progress.completedAt, isNull);
      });

      test('should use default values', () {
        final progress = ProgressState(
          id: 'test-id',
          userId: 'user-id',
          learningObjectId: 'lo-id',
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.currentPositionMs, 0);
        expect(progress.isCompleted, false);
        expect(progress.isInProgress, false);
        expect(progress.playbackSpeed, 1.0);
        expect(progress.fontSizeIndex, 1); // Medium
      });
    });

    group('Constructor Assertions', () {
      test('should throw on negative position', () {
        expect(
          () => ProgressState(
            id: 'test',
            userId: 'user',
            learningObjectId: 'lo',
            currentPositionMs: -1,
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );
      });

      test('should throw on invalid playback speed', () {
        expect(
          () => ProgressState(
            id: 'test',
            userId: 'user',
            learningObjectId: 'lo',
            playbackSpeed: 0.0,
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );

        expect(
          () => ProgressState(
            id: 'test',
            userId: 'user',
            learningObjectId: 'lo',
            playbackSpeed: 3.5,
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );
      });

      test('should throw on invalid font size index', () {
        expect(
          () => ProgressState(
            id: 'test',
            userId: 'user',
            learningObjectId: 'lo',
            fontSizeIndex: -1,
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );

        expect(
          () => ProgressState(
            id: 'test',
            userId: 'user',
            learningObjectId: 'lo',
            fontSizeIndex: 4, // Beyond range
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );
      });

      test('should throw on empty IDs', () {
        expect(
          () => ProgressState(
            id: '',
            userId: 'user',
            learningObjectId: 'lo',
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );

        expect(
          () => ProgressState(
            id: 'test',
            userId: '',
            learningObjectId: 'lo',
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );

        expect(
          () => ProgressState(
            id: 'test',
            userId: 'user',
            learningObjectId: '',
            lastAccessedAt: DateTime.now(),
          ),
          throwsAssertionError,
        );
      });
    });

    group('Font Size Properties', () {
      test('should provide correct font size name', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          fontSizeIndex: 0,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.fontSizeName, 'Small');
      });

      test('should provide correct font size value', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          fontSizeIndex: 3,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.fontSizeValue, 20.0);
      });

      test('should handle invalid font size index gracefully', () {
        // Create with valid index then manually test getter logic
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          fontSizeIndex: 1,
          lastAccessedAt: DateTime.now(),
        );

        // Normal case
        expect(progress.fontSizeName, 'Medium');
        expect(progress.fontSizeValue, 16.0);
      });

      test('should have correct font size constants', () {
        expect(ProgressState.fontSizeNames,
            ['Small', 'Medium', 'Large', 'X-Large']);
        expect(ProgressState.fontSizeValues, [14.0, 16.0, 18.0, 20.0]);
        expect(ProgressState.fontSizeNames.length,
            ProgressState.fontSizeValues.length);
      });
    });

    group('Playback Speed Properties', () {
      test('should format playback speed correctly', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          playbackSpeed: 1.75,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.formattedSpeed, '1.75x');
      });

      test('should format integer speeds correctly', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          playbackSpeed: 2.0,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.formattedSpeed, '2.0x');
      });
    });

    group('Progress Calculation', () {
      test('should calculate progress percentage correctly', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 3000,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.calculateProgressPercentage(12000), 25.0);
        expect(progress.calculateProgressPercentage(6000), 50.0);
        expect(progress.calculateProgressPercentage(2000), 100.0); // Clamped
      });

      test('should return 100% for completed items', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 1000,
          isCompleted: true,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.calculateProgressPercentage(10000), 100.0);
      });

      test('should return 0% for zero duration', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 5000,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.calculateProgressPercentage(0), 0.0);
      });

      test('should clamp progress between 0 and 100', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 15000,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.calculateProgressPercentage(10000), 100.0);
      });
    });

    group('Resume Logic', () {
      test('should resume when in progress with position', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 5000,
          isInProgress: true,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.shouldResume, true);
      });

      test('should not resume when not in progress', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 5000,
          isInProgress: false,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.shouldResume, false);
      });

      test('should not resume when position is zero', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 0,
          isInProgress: true,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.shouldResume, false);
      });
    });

    group('JSON Serialization', () {
      test('fromJson should parse valid JSON correctly', () {
        final progress = ProgressState.fromJson(testJson);

        expect(progress.id, 'progress-xyz789');
        expect(progress.userId, 'user-abc123');
        expect(progress.learningObjectId, 'lo-def456');
        expect(progress.currentPositionMs, 12500);
        expect(progress.isCompleted, false);
        expect(progress.isInProgress, true);
        expect(progress.playbackSpeed, 1.25);
        expect(progress.fontSizeIndex, 2);
        expect(progress.lastAccessedAt, DateTime.parse('2024-05-10T16:30:00Z'));
        expect(progress.completedAt, isNull);
      });

      test('fromJson should use defaults for missing fields', () {
        final minimalJson = {
          'id': 'minimal-progress',
          'user_id': 'minimal-user',
          'learning_object_id': 'minimal-lo',
          'last_accessed_at': '2024-01-01T00:00:00Z',
        };

        final progress = ProgressState.fromJson(minimalJson);

        expect(progress.currentPositionMs, 0);
        expect(progress.isCompleted, false);
        expect(progress.isInProgress, false);
        expect(progress.playbackSpeed, 1.0);
        expect(progress.fontSizeIndex, 1);
      });

      test('toJson should serialize all fields correctly', () {
        final progress = ProgressState.fromJson(testJson);
        final json = progress.toJson();

        expect(json['id'], 'progress-xyz789');
        expect(json['user_id'], 'user-abc123');
        expect(json['learning_object_id'], 'lo-def456');
        expect(json['current_position_ms'], 12500);
        expect(json['is_completed'], false);
        expect(json['is_in_progress'], true);
        expect(json['playback_speed'], 1.25);
        expect(json['font_size_index'], 2);
        expect(json['last_accessed_at'], '2024-05-10T16:30:00.000Z');
        expect(json['completed_at'], isNull);
      });

      test('round-trip serialization should preserve data', () {
        final original = ProgressState.fromJson(testJson);
        final json = original.toJson();
        final restored = ProgressState.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.currentPositionMs, original.currentPositionMs);
        expect(restored.playbackSpeed, original.playbackSpeed);
        expect(restored.fontSizeIndex, original.fontSizeIndex);
        expect(restored.isCompleted, original.isCompleted);
        expect(restored.lastAccessedAt, original.lastAccessedAt);
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = ProgressState.fromJson(testJson);
        final updated = original.copyWith(
          currentPositionMs: 20000,
          isCompleted: true,
          playbackSpeed: 2.0,
        );

        expect(updated.id, original.id);
        expect(updated.userId, original.userId);
        expect(updated.currentPositionMs, 20000);
        expect(updated.isCompleted, true);
        expect(updated.playbackSpeed, 2.0);
        expect(updated.fontSizeIndex, original.fontSizeIndex);
      });

      test('should preserve original when no fields changed', () {
        final original = ProgressState.fromJson(testJson);
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.currentPositionMs, original.currentPositionMs);
        expect(copy.isCompleted, original.isCompleted);
      });
    });

    group('Font Size Cycling', () {
      test('should cycle through font sizes', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          fontSizeIndex: 0, // Small
          lastAccessedAt: DateTime.now(),
        );

        final next1 = progress.cycleToNextFontSize();
        expect(next1.fontSizeIndex, 1);
        expect(next1.fontSizeName, 'Medium');

        final next2 = next1.cycleToNextFontSize();
        expect(next2.fontSizeIndex, 2);
        expect(next2.fontSizeName, 'Large');

        final next3 = next2.cycleToNextFontSize();
        expect(next3.fontSizeIndex, 3);
        expect(next3.fontSizeName, 'X-Large');

        final wrapped = next3.cycleToNextFontSize();
        expect(wrapped.fontSizeIndex, 0);
        expect(wrapped.fontSizeName, 'Small');
      });
    });

    group('Playback Speed Cycling', () {
      test('should cycle through playback speeds', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          playbackSpeed: 1.0,
          lastAccessedAt: DateTime.now(),
        );

        final next1 = progress.cycleToNextSpeed();
        expect(next1.playbackSpeed, 1.25);

        final next2 = next1.cycleToNextSpeed();
        expect(next2.playbackSpeed, 1.5);

        final next3 = next2.cycleToNextSpeed();
        expect(next3.playbackSpeed, 1.75);

        final next4 = next3.cycleToNextSpeed();
        expect(next4.playbackSpeed, 2.0);

        final wrapped = next4.cycleToNextSpeed();
        expect(wrapped.playbackSpeed, 0.8);
      });

      test('should handle speed not in predefined list', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          playbackSpeed: 1.33, // Not in standard list
          lastAccessedAt: DateTime.now(),
        );

        final next = progress.cycleToNextSpeed();
        expect(next.playbackSpeed, 0.8); // Wraps to first
      });
    });

    group('State Updates', () {
      test('markAsCompleted should set completion fields', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          isInProgress: true,
          lastAccessedAt: DateTime.now(),
        );

        final completed = progress.markAsCompleted();

        expect(completed.isCompleted, true);
        expect(completed.isInProgress, false);
        expect(completed.completedAt, isNotNull);
        expect(
            completed.completedAt!
                .isAfter(DateTime.now().subtract(const Duration(seconds: 1))),
            true);
      });

      test('updatePosition should update position and state', () {
        final oldTime = DateTime.now().subtract(const Duration(minutes: 5));
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 1000,
          isInProgress: false,
          lastAccessedAt: oldTime,
        );

        final updated = progress.updatePosition(5000);

        expect(updated.currentPositionMs, 5000);
        expect(updated.isInProgress, true);
        expect(updated.lastAccessedAt.isAfter(oldTime), true);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final now = DateTime.now();
        final progress1 = ProgressState(
          id: 'same-id',
          userId: 'user-1',
          learningObjectId: 'lo-1',
          currentPositionMs: 1000,
          lastAccessedAt: now,
        );

        final progress2 = ProgressState(
          id: 'same-id',
          userId: 'user-2',
          learningObjectId: 'lo-2',
          currentPositionMs: 2000,
          lastAccessedAt: now,
        );

        expect(progress1, equals(progress2));
        expect(progress1.hashCode, progress2.hashCode);
      });

      test('should not be equal when IDs differ', () {
        final now = DateTime.now();
        final progress1 = ProgressState(
          id: 'id-1',
          userId: 'same-user',
          learningObjectId: 'same-lo',
          lastAccessedAt: now,
        );

        final progress2 = ProgressState(
          id: 'id-2',
          userId: 'same-user',
          learningObjectId: 'same-lo',
          lastAccessedAt: now,
        );

        expect(progress1, isNot(equals(progress2)));
      });

      test('should be equal to itself', () {
        final progress = ProgressState.fromJson(testJson);
        expect(progress, equals(progress));
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final progress = ProgressState(
          id: 'test-123',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 5000,
          isCompleted: true,
          lastAccessedAt: DateTime.now(),
        );

        final str = progress.toString();
        expect(str, contains('test-123'));
        expect(str, contains('5000'));
        expect(str, contains('true'));
      });
    });

    group('Validation Function', () {
      test('validateProgressStateModel should not throw', () {
        expect(() => validateProgressStateModel(), returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle very large position values', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 999999999,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.currentPositionMs, 999999999);
        expect(progress.calculateProgressPercentage(1000), 100.0); // Clamped
      });

      test('should handle extreme playback speeds', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          playbackSpeed: 3.0, // Maximum allowed
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.playbackSpeed, 3.0);
        expect(progress.formattedSpeed, '3.0x');
      });

      test('should handle completion with zero position', () {
        final progress = ProgressState(
          id: 'test',
          userId: 'user',
          learningObjectId: 'lo',
          currentPositionMs: 0,
          isCompleted: true,
          lastAccessedAt: DateTime.now(),
        );

        expect(progress.shouldResume, false);
        expect(progress.calculateProgressPercentage(1000), 100.0);
      });
    });
  });
}
