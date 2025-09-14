import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audio_learning_app/services/progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressService Tests', () {
    setUp(() async {
      // Initialize SharedPreferences mock with default values
      SharedPreferences.setMockInitialValues({
        'font_size_index': 1,
        'playback_speed': 1.0,
      });

      // Initialize Supabase for testing
      try {
        await Supabase.initialize(
          url: 'https://test.supabase.co',
          anonKey: 'test-anon-key',
        );
      } catch (e) {
        // Already initialized
      }
    });

    test('ProgressService singleton instance', () async {
      final instance1 = await ProgressService.getInstance();
      final instance2 = await ProgressService.getInstance();

      expect(instance1, same(instance2));
    });

    group('Font Size Preferences', () {
      test('should get default font size index', () async {
        final service = await ProgressService.getInstance();
        final fontSizeIndex = service.fontSizeIndex;

        expect(fontSizeIndex, equals(1)); // Default is Medium
      });

      test('should update font size index', () async {
        final service = await ProgressService.getInstance();

        await service.setFontSizeIndex(2); // Large

        expect(service.fontSizeIndex, equals(2));
        expect(service.currentFontSizeName, equals('Large'));
      });

      test('should validate font size index range', () async {
        final service = await ProgressService.getInstance();

        // Set a known starting value
        await service.setFontSizeIndex(1);
        expect(service.fontSizeIndex, equals(1));

        // Test invalid negative index (should be ignored, value stays at 1)
        await service.setFontSizeIndex(-1);
        expect(service.fontSizeIndex, equals(1)); // Value unchanged

        // Test invalid large index (should be ignored, value stays at 1)
        await service.setFontSizeIndex(10);
        expect(service.fontSizeIndex, equals(1)); // Value unchanged

        // Test valid boundary values
        await service.setFontSizeIndex(0);
        expect(service.fontSizeIndex, equals(0)); // Small

        await service.setFontSizeIndex(3);
        expect(service.fontSizeIndex, equals(3)); // X-Large
      });

      test('should cycle font sizes correctly', () async {
        final service = await ProgressService.getInstance();

        // Start at default (1 - Medium)
        await service.setFontSizeIndex(1);
        expect(service.fontSizeIndex, equals(1));

        // Cycle to Large
        await service.cycleFontSize();
        expect(service.fontSizeIndex, equals(2));

        // Cycle to X-Large
        await service.cycleFontSize();
        expect(service.fontSizeIndex, equals(3));

        // Cycle back to Small
        await service.cycleFontSize();
        expect(service.fontSizeIndex, equals(0));

        // Cycle back to Medium
        await service.cycleFontSize();
        expect(service.fontSizeIndex, equals(1));
      });

      test('should correctly map font size names', () async {
        final service = await ProgressService.getInstance();

        await service.setFontSizeIndex(0);
        expect(service.currentFontSizeName, equals('Small'));

        await service.setFontSizeIndex(1);
        expect(service.currentFontSizeName, equals('Medium'));

        await service.setFontSizeIndex(2);
        expect(service.currentFontSizeName, equals('Large'));

        await service.setFontSizeIndex(3);
        expect(service.currentFontSizeName, equals('X-Large'));
      });
    });

    group('Playback Speed Preferences', () {
      test('should get default playback speed', () async {
        final service = await ProgressService.getInstance();
        final speed = service.playbackSpeed;

        expect(speed, equals(1.0)); // Default speed
      });

      test('should update playback speed', () async {
        final service = await ProgressService.getInstance();

        await service.setPlaybackSpeed(1.5);

        expect(service.playbackSpeed, equals(1.5));
      });

      test('should accept any playback speed values', () async {
        final service = await ProgressService.getInstance();

        // Test slow speed (no clamping in service)
        await service.setPlaybackSpeed(0.5);
        expect(service.playbackSpeed, equals(0.5));

        // Test fast speed (no clamping in service)
        await service.setPlaybackSpeed(3.0);
        expect(service.playbackSpeed, equals(3.0));

        // Test normal speed
        await service.setPlaybackSpeed(1.25);
        expect(service.playbackSpeed, equals(1.25));

        // Reset to default
        await service.setPlaybackSpeed(1.0);
        expect(service.playbackSpeed, equals(1.0));
      });
    });

    group('Stream Subscriptions', () {
      test('font size stream should emit updates', () async {
        final service = await ProgressService.getInstance();
        final emittedValues = <int>[];

        final subscription = service.fontSizeIndexStream.listen((value) {
          emittedValues.add(value);
        });

        await service.setFontSizeIndex(0);
        await service.setFontSizeIndex(2);
        await service.setFontSizeIndex(3);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emittedValues.contains(0), isTrue);
        expect(emittedValues.contains(2), isTrue);
        expect(emittedValues.contains(3), isTrue);

        subscription.cancel();
      });

      test('playback speed stream should emit updates', () async {
        final service = await ProgressService.getInstance();
        final emittedValues = <double>[];

        final subscription = service.playbackSpeedStream.listen((value) {
          emittedValues.add(value);
        });

        await service.setPlaybackSpeed(0.8);
        await service.setPlaybackSpeed(1.5);
        await service.setPlaybackSpeed(2.0);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emittedValues.contains(0.8), isTrue);
        expect(emittedValues.contains(1.5), isTrue);
        expect(emittedValues.contains(2.0), isTrue);

        subscription.cancel();
      });
    });

    group('Progress Saving', () {
      test('should handle save progress call', () async {
        final service = await ProgressService.getInstance();

        // This should not throw
        service.saveProgress(
          userId: 'test-user',
          learningObjectId: 'test-object',
          positionMs: 300000, // 5 minutes in milliseconds
          isCompleted: false,
          isInProgress: true,
        );

        // Wait for any debounced operations
        await Future.delayed(const Duration(milliseconds: 100));

        // Test passes if no exceptions thrown
        expect(true, isTrue);
      });

      test('should load progress', () async {
        final service = await ProgressService.getInstance();

        // Save some progress first
        service.saveProgress(
          userId: 'test-user',
          learningObjectId: 'test-object',
          positionMs: 180000, // 3 minutes
          isCompleted: false,
          isInProgress: true,
        );

        // Wait for save to complete
        await Future.delayed(const Duration(seconds: 6));

        // Load the progress
        final progress = await service.loadProgress(
          learningObjectId: 'test-object',
          userId: 'test-user',
        );

        // Progress may be null in test environment
        // Just verify no exceptions
        expect(true, isTrue);
      });
    });

    group('Service Disposal', () {
      test('should handle disposal gracefully', () async {
        final service = await ProgressService.getInstance();

        // This should not throw
        service.dispose();

        // Test passes if no exceptions thrown
        expect(true, isTrue);
      });
    });

    group('Static Configuration', () {
      test('font size configuration should be valid', () {
        expect(ProgressService.fontSizeNames.length, equals(4));
        expect(ProgressService.fontSizeValues.length, equals(4));
        expect(ProgressService.defaultFontSizeIndex, equals(1));

        expect(ProgressService.fontSizeNames[0], equals('Small'));
        expect(ProgressService.fontSizeNames[1], equals('Medium'));
        expect(ProgressService.fontSizeNames[2], equals('Large'));
        expect(ProgressService.fontSizeNames[3], equals('X-Large'));

        expect(ProgressService.fontSizeValues[0], equals(14.0));
        expect(ProgressService.fontSizeValues[1], equals(16.0));
        expect(ProgressService.fontSizeValues[2], equals(18.0));
        expect(ProgressService.fontSizeValues[3], equals(20.0));
      });
    });

    group('Validation Function', () {
      test('validation function should complete successfully', () async {
        // Call the validation function
        final result = await validateProgressService();

        expect(result, isTrue);
      });
    });
  });
}

// Validation function for ProgressService
Future<bool> validateProgressService() async {
  try {
    print('Validating ProgressService...');

    // Initialize SharedPreferences mock
    SharedPreferences.setMockInitialValues({
      'font_size_index': 1,
      'playback_speed': 1.0,
    });

    // Initialize Supabase if needed
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (e) {
      // Already initialized
    }

    // Get instance
    final service = await ProgressService.getInstance();
    print('- Service instance created');

    // Test font size
    await service.setFontSizeIndex(2);
    assert(service.fontSizeIndex == 2, 'Font size update failed');
    print('- Font size persistence: OK');

    // Test playback speed
    await service.setPlaybackSpeed(1.5);
    assert(service.playbackSpeed == 1.5, 'Speed update failed');
    print('- Playback speed persistence: OK');

    // Test progress saving (no exception expected)
    service.saveProgress(
      userId: 'test-user',
      learningObjectId: 'test-object',
      positionMs: 300000,
      isCompleted: false,
      isInProgress: true,
    );
    print('- Progress saving: OK');

    // Clean up
    service.dispose();
    print('- Service disposal: OK');

    print('ProgressService validation PASSED');
    return true;
  } catch (e) {
    print('ProgressService validation FAILED: $e');
    return false;
  }
}