import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_learning_app/providers/ui_providers.dart';
import 'package:audio_learning_app/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('fontSizeIndexProvider', () {
      test('should provide FontSizeNotifier instance', () {
        final notifier = container.read(fontSizeIndexProvider.notifier);
        expect(notifier, isA<FontSizeNotifier>());
      });

      test('should start with default medium size (index 1)', () {
        final fontSize = container.read(fontSizeIndexProvider);
        expect(fontSize, 1); // Medium is index 1
      });

      test('should allow reading current font size', () {
        final fontSize = container.read(fontSizeIndexProvider);
        expect(fontSize, isA<int>());
        expect(fontSize, greaterThanOrEqualTo(0));
        expect(fontSize, lessThan(ProgressState.fontSizeNames.length));
      });

      test('should notify listeners when font size changes', () {
        var notificationCount = 0;
        
        container.listen(
          fontSizeIndexProvider,
          (previous, next) => notificationCount++,
        );

        final notifier = container.read(fontSizeIndexProvider.notifier);
        notifier.setFontSize(2);
        
        expect(notificationCount, 1);
        expect(container.read(fontSizeIndexProvider), 2);
      });
    });

    group('FontSizeNotifier', () {
      test('should initialize with medium size (index 1)', () {
        final notifier = FontSizeNotifier();
        expect(notifier.state, 1);
      });

      test('should set font size within valid range', () {
        final notifier = FontSizeNotifier();
        
        notifier.setFontSize(0); // Small
        expect(notifier.state, 0);
        
        notifier.setFontSize(2); // Large
        expect(notifier.state, 2);
        
        notifier.setFontSize(3); // X-Large
        expect(notifier.state, 3);
      });

      test('should ignore invalid font size indices', () {
        final notifier = FontSizeNotifier();
        final initialSize = notifier.state;
        
        notifier.setFontSize(-1);
        expect(notifier.state, initialSize);
        
        notifier.setFontSize(99);
        expect(notifier.state, initialSize);
      });

      test('should cycle to next font size', () {
        final notifier = FontSizeNotifier();
        
        notifier.setFontSize(0); // Start at Small
        expect(notifier.state, 0);
        
        notifier.cycleToNext();
        expect(notifier.state, 1); // Medium
        
        notifier.cycleToNext();
        expect(notifier.state, 2); // Large
        
        notifier.cycleToNext();
        expect(notifier.state, 3); // X-Large
        
        notifier.cycleToNext();
        expect(notifier.state, 0); // Wrap back to Small
      });

      test('should provide font size name', () {
        final notifier = FontSizeNotifier();
        
        notifier.setFontSize(0);
        expect(notifier.fontSizeName, ProgressState.fontSizeNames[0]);
        
        notifier.setFontSize(1);
        expect(notifier.fontSizeName, ProgressState.fontSizeNames[1]);
        
        notifier.setFontSize(2);
        expect(notifier.fontSizeName, ProgressState.fontSizeNames[2]);
        
        notifier.setFontSize(3);
        expect(notifier.fontSizeName, ProgressState.fontSizeNames[3]);
      });

      test('should provide font size value', () {
        final notifier = FontSizeNotifier();
        
        notifier.setFontSize(0);
        expect(notifier.fontSizeValue, ProgressState.fontSizeValues[0]);
        
        notifier.setFontSize(1);
        expect(notifier.fontSizeValue, ProgressState.fontSizeValues[1]);
        
        notifier.setFontSize(2);
        expect(notifier.fontSizeValue, ProgressState.fontSizeValues[2]);
        
        notifier.setFontSize(3);
        expect(notifier.fontSizeValue, ProgressState.fontSizeValues[3]);
      });

      test('should handle all valid font sizes', () {
        final notifier = FontSizeNotifier();
        
        for (int i = 0; i < ProgressState.fontSizeNames.length; i++) {
          notifier.setFontSize(i);
          expect(notifier.state, i);
          expect(notifier.fontSizeName, ProgressState.fontSizeNames[i]);
          expect(notifier.fontSizeValue, ProgressState.fontSizeValues[i]);
        }
      });
    });

    group('playbackSpeedProvider', () {
      test('should provide PlaybackSpeedNotifier instance', () {
        final notifier = container.read(playbackSpeedProvider.notifier);
        expect(notifier, isA<PlaybackSpeedNotifier>());
      });

      test('should start with default speed (1.0x)', () {
        final speed = container.read(playbackSpeedProvider);
        expect(speed, 1.0);
      });

      test('should allow reading current playback speed', () {
        final speed = container.read(playbackSpeedProvider);
        expect(speed, isA<double>());
        expect(speed, greaterThan(0.0));
      });

      test('should notify listeners when speed changes', () {
        var notificationCount = 0;
        
        container.listen(
          playbackSpeedProvider,
          (previous, next) => notificationCount++,
        );

        final notifier = container.read(playbackSpeedProvider.notifier);
        notifier.setSpeed(1.5);
        
        expect(notificationCount, 1);
        expect(container.read(playbackSpeedProvider), 1.5);
      });
    });

    group('PlaybackSpeedNotifier', () {
      test('should initialize with normal speed (1.0x)', () {
        final notifier = PlaybackSpeedNotifier();
        expect(notifier.state, 1.0);
      });

      test('should have predefined speed options', () {
        final expectedSpeeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
        expect(PlaybackSpeedNotifier.speeds, expectedSpeeds);
      });

      test('should set speed from predefined options', () {
        final notifier = PlaybackSpeedNotifier();
        
        notifier.setSpeed(0.8);
        expect(notifier.state, 0.8);
        
        notifier.setSpeed(1.25);
        expect(notifier.state, 1.25);
        
        notifier.setSpeed(2.0);
        expect(notifier.state, 2.0);
      });

      test('should ignore invalid speeds', () {
        final notifier = PlaybackSpeedNotifier();
        final initialSpeed = notifier.state;
        
        notifier.setSpeed(0.5); // Not in predefined list
        expect(notifier.state, initialSpeed);
        
        notifier.setSpeed(3.0); // Not in predefined list
        expect(notifier.state, initialSpeed);
        
        notifier.setSpeed(-1.0); // Invalid
        expect(notifier.state, initialSpeed);
      });

      test('should cycle through all speed options', () {
        final notifier = PlaybackSpeedNotifier();
        final expectedSpeeds = PlaybackSpeedNotifier.speeds;
        
        // Start at first speed
        notifier.setSpeed(expectedSpeeds[0]);
        expect(notifier.state, expectedSpeeds[0]);
        
        // Cycle through all speeds
        for (int i = 1; i < expectedSpeeds.length; i++) {
          notifier.cycleToNext();
          expect(notifier.state, expectedSpeeds[i]);
        }
        
        // Should wrap back to first speed
        notifier.cycleToNext();
        expect(notifier.state, expectedSpeeds[0]);
      });

      test('should provide formatted speed string', () {
        final notifier = PlaybackSpeedNotifier();
        
        notifier.setSpeed(0.8);
        expect(notifier.formattedSpeed, '0.8x');
        
        notifier.setSpeed(1.0);
        expect(notifier.formattedSpeed, '1.0x');
        
        notifier.setSpeed(1.25);
        expect(notifier.formattedSpeed, '1.25x');
        
        notifier.setSpeed(1.5);
        expect(notifier.formattedSpeed, '1.5x');
        
        notifier.setSpeed(1.75);
        expect(notifier.formattedSpeed, '1.75x');
        
        notifier.setSpeed(2.0);
        expect(notifier.formattedSpeed, '2.0x');
      });

      test('should handle cycling from any starting position', () {
        final notifier = PlaybackSpeedNotifier();
        final speeds = PlaybackSpeedNotifier.speeds;
        
        // Test cycling from middle of list
        notifier.setSpeed(1.25); // Index 2
        notifier.cycleToNext();
        expect(notifier.state, 1.5); // Index 3
        
        // Test cycling from end of list
        notifier.setSpeed(2.0); // Last speed
        notifier.cycleToNext();
        expect(notifier.state, 0.8); // First speed
      });

      test('should maintain valid speeds only', () {
        final notifier = PlaybackSpeedNotifier();
        final speeds = PlaybackSpeedNotifier.speeds;
        
        for (final speed in speeds) {
          notifier.setSpeed(speed);
          expect(notifier.state, speed);
          expect(speeds, contains(notifier.state));
        }
      });
    });

    group('Provider Integration', () {
      test('both providers should work independently', () {
        final fontNotifier = container.read(fontSizeIndexProvider.notifier);
        final speedNotifier = container.read(playbackSpeedProvider.notifier);
        
        // Change font size
        fontNotifier.setFontSize(2);
        expect(container.read(fontSizeIndexProvider), 2);
        
        // Change speed
        speedNotifier.setSpeed(1.5);
        expect(container.read(playbackSpeedProvider), 1.5);
        
        // Both should maintain their values
        expect(container.read(fontSizeIndexProvider), 2);
        expect(container.read(playbackSpeedProvider), 1.5);
      });

      test('should handle concurrent updates', () {
        var fontNotifications = 0;
        var speedNotifications = 0;
        
        container.listen(
          fontSizeIndexProvider,
          (previous, next) => fontNotifications++,
        );
        
        container.listen(
          playbackSpeedProvider,
          (previous, next) => speedNotifications++,
        );
        
        final fontNotifier = container.read(fontSizeIndexProvider.notifier);
        final speedNotifier = container.read(playbackSpeedProvider.notifier);
        
        // Make multiple changes
        fontNotifier.cycleToNext();
        speedNotifier.cycleToNext();
        fontNotifier.cycleToNext();
        speedNotifier.setSpeed(0.8);
        
        expect(fontNotifications, 2);
        expect(speedNotifications, 2);
      });
    });

    group('State Persistence', () {
      test('font size should maintain state across reads', () {
        final notifier = container.read(fontSizeIndexProvider.notifier);
        
        notifier.setFontSize(3);
        expect(container.read(fontSizeIndexProvider), 3);
        
        // Multiple reads should return same value
        expect(container.read(fontSizeIndexProvider), 3);
        expect(container.read(fontSizeIndexProvider), 3);
      });

      test('playback speed should maintain state across reads', () {
        final notifier = container.read(playbackSpeedProvider.notifier);
        
        notifier.setSpeed(1.75);
        expect(container.read(playbackSpeedProvider), 1.75);
        
        // Multiple reads should return same value
        expect(container.read(playbackSpeedProvider), 1.75);
        expect(container.read(playbackSpeedProvider), 1.75);
      });
    });

    group('Edge Cases', () {
      test('should handle rapid cycling', () {
        final fontNotifier = container.read(fontSizeIndexProvider.notifier);
        final speedNotifier = container.read(playbackSpeedProvider.notifier);
        
        // Rapid font size cycling
        for (int i = 0; i < 20; i++) {
          fontNotifier.cycleToNext();
        }
        
        // Should still be in valid range
        final fontSize = container.read(fontSizeIndexProvider);
        expect(fontSize, greaterThanOrEqualTo(0));
        expect(fontSize, lessThan(ProgressState.fontSizeNames.length));
        
        // Rapid speed cycling
        for (int i = 0; i < 20; i++) {
          speedNotifier.cycleToNext();
        }
        
        // Should still be valid speed
        final speed = container.read(playbackSpeedProvider);
        expect(PlaybackSpeedNotifier.speeds, contains(speed));
      });

      test('should handle boundary conditions', () {
        final fontNotifier = FontSizeNotifier();
        final speedNotifier = PlaybackSpeedNotifier();
        
        // Test font size boundaries
        fontNotifier.setFontSize(0);
        expect(fontNotifier.state, 0);
        
        fontNotifier.setFontSize(ProgressState.fontSizeNames.length - 1);
        expect(fontNotifier.state, ProgressState.fontSizeNames.length - 1);
        
        // Test speed boundaries
        speedNotifier.setSpeed(PlaybackSpeedNotifier.speeds.first);
        expect(speedNotifier.state, PlaybackSpeedNotifier.speeds.first);
        
        speedNotifier.setSpeed(PlaybackSpeedNotifier.speeds.last);
        expect(speedNotifier.state, PlaybackSpeedNotifier.speeds.last);
      });
    });

    group('Provider Lifecycle', () {
      test('providers should be disposable', () {
        final testContainer = ProviderContainer();
        
        testContainer.read(fontSizeIndexProvider);
        testContainer.read(playbackSpeedProvider);
        
        expect(() => testContainer.dispose(), returnsNormally);
      });

      test('should handle provider recreation', () {
        final testContainer = ProviderContainer();
        final fontNotifier1 = testContainer.read(fontSizeIndexProvider.notifier);
        final speedNotifier1 = testContainer.read(playbackSpeedProvider.notifier);
        testContainer.dispose();
        
        final newContainer = ProviderContainer();
        final fontNotifier2 = newContainer.read(fontSizeIndexProvider.notifier);
        final speedNotifier2 = newContainer.read(playbackSpeedProvider.notifier);
        
        // Should be different instances
        expect(identical(fontNotifier1, fontNotifier2), isFalse);
        expect(identical(speedNotifier1, speedNotifier2), isFalse);
        
        // Should start with default values
        expect(newContainer.read(fontSizeIndexProvider), 1); // Medium
        expect(newContainer.read(playbackSpeedProvider), 1.0); // 1.0x
        
        newContainer.dispose();
      });
    });

    group('Model Integration', () {
      test('should use ProgressState font size constants', () {
        final notifier = FontSizeNotifier();
        
        // Verify it uses the same constants as ProgressState
        expect(notifier.fontSizeName, isA<String>());
        expect(notifier.fontSizeValue, isA<double>());
        
        // Test all indices
        for (int i = 0; i < ProgressState.fontSizeNames.length; i++) {
          notifier.setFontSize(i);
          expect(notifier.fontSizeName, ProgressState.fontSizeNames[i]);
          expect(notifier.fontSizeValue, ProgressState.fontSizeValues[i]);
        }
      });

      test('should handle font size array consistency', () {
        expect(ProgressState.fontSizeNames.length, ProgressState.fontSizeValues.length);
        expect(ProgressState.fontSizeNames.length, greaterThan(0));
        expect(ProgressState.fontSizeValues.length, greaterThan(0));
      });
    });

    group('Performance', () {
      test('should handle frequent state changes efficiently', () {
        final fontNotifier = container.read(fontSizeIndexProvider.notifier);
        final speedNotifier = container.read(playbackSpeedProvider.notifier);
        
        // Perform many state changes
        for (int i = 0; i < 1000; i++) {
          fontNotifier.cycleToNext();
          speedNotifier.cycleToNext();
        }
        
        // Should still be responsive and valid
        final fontSize = container.read(fontSizeIndexProvider);
        final speed = container.read(playbackSpeedProvider);
        
        expect(fontSize, greaterThanOrEqualTo(0));
        expect(fontSize, lessThan(ProgressState.fontSizeNames.length));
        expect(PlaybackSpeedNotifier.speeds, contains(speed));
      });
    });
  });
}