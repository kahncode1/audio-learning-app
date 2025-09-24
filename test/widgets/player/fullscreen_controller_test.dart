import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/widgets/player/fullscreen_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FullscreenController', () {
    late FullscreenController controller;
    late bool fullscreenChangedCalled;
    late bool lastFullscreenValue;

    setUp(() {
      fullscreenChangedCalled = false;
      lastFullscreenValue = false;

      controller = FullscreenController(
        onFullscreenChanged: (isFullscreen) {
          fullscreenChangedCalled = true;
          lastFullscreenValue = isFullscreen;
        },
      );

      // Reset system UI mode to default
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'SystemChrome.setEnabledSystemUIMode') {
            return null;
          }
          return null;
        },
      );
    });

    tearDown(() {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('should start with fullscreen disabled', () {
      expect(controller.isFullscreen, isFalse);
    });

    test('should enter fullscreen mode', () {
      controller.enterFullscreen();

      expect(controller.isFullscreen, isTrue);
      expect(fullscreenChangedCalled, isTrue);
      expect(lastFullscreenValue, isTrue);
    });

    test('should exit fullscreen mode', () {
      // First enter fullscreen
      controller.enterFullscreen();

      // Reset tracking variables
      fullscreenChangedCalled = false;
      lastFullscreenValue = true;

      // Now exit fullscreen
      controller.exitFullscreen();

      expect(controller.isFullscreen, isFalse);
      expect(fullscreenChangedCalled, isTrue);
      expect(lastFullscreenValue, isFalse);
    });

    test('should not call onFullscreenChanged when already in fullscreen', () {
      controller.enterFullscreen();

      // Reset tracking
      fullscreenChangedCalled = false;

      // Try to enter fullscreen again
      controller.enterFullscreen();

      expect(fullscreenChangedCalled, isFalse);
      expect(controller.isFullscreen, isTrue);
    });

    test('should not call onFullscreenChanged when already not in fullscreen', () {
      // Ensure we're not in fullscreen
      expect(controller.isFullscreen, isFalse);

      // Try to exit fullscreen when not in fullscreen
      controller.exitFullscreen();

      expect(fullscreenChangedCalled, isFalse);
      expect(controller.isFullscreen, isFalse);
    });

    test('should start fullscreen timer', () async {
      controller.startFullscreenTimer();

      // Timer should be created but fullscreen not activated yet
      expect(controller.isFullscreen, isFalse);

      // Wait for timer to complete (3 seconds)
      await Future.delayed(const Duration(seconds: 4));

      expect(controller.isFullscreen, isTrue);
      expect(fullscreenChangedCalled, isTrue);
      expect(lastFullscreenValue, isTrue);
    });

    test('should cancel fullscreen timer', () async {
      controller.startFullscreenTimer();

      // Cancel before timer completes
      controller.cancelFullscreenTimer();

      // Wait to ensure timer doesn't fire
      await Future.delayed(const Duration(seconds: 4));

      expect(controller.isFullscreen, isFalse);
      expect(fullscreenChangedCalled, isFalse);
    });

    test('should restart timer when already running', () async {
      controller.startFullscreenTimer();

      // Wait 2 seconds
      await Future.delayed(const Duration(seconds: 2));

      // Restart timer (should cancel old one and start new)
      controller.startFullscreenTimer();

      // Wait 2 more seconds (4 total, but timer restarted at 2)
      await Future.delayed(const Duration(seconds: 2));

      // Should not be in fullscreen yet (only 2 seconds since restart)
      expect(controller.isFullscreen, isFalse);

      // Wait 2 more seconds for new timer to complete
      await Future.delayed(const Duration(seconds: 2));

      expect(controller.isFullscreen, isTrue);
    });

    test('restartTimerOnInteraction should exit fullscreen and restart timer', () async {
      // First enter fullscreen
      controller.enterFullscreen();
      expect(controller.isFullscreen, isTrue);

      // Reset tracking
      fullscreenChangedCalled = false;

      // Call restartTimerOnInteraction
      controller.restartTimerOnInteraction();

      // Should exit fullscreen
      expect(controller.isFullscreen, isFalse);
      expect(fullscreenChangedCalled, isTrue);
      expect(lastFullscreenValue, isFalse);

      // Timer should be running, wait for it
      await Future.delayed(const Duration(seconds: 4));

      // Should be back in fullscreen
      expect(controller.isFullscreen, isTrue);
    });

    test('restartTimerOnInteraction should just restart timer when not in fullscreen', () async {
      // Ensure not in fullscreen
      expect(controller.isFullscreen, isFalse);

      controller.restartTimerOnInteraction();

      // Should still not be in fullscreen
      expect(controller.isFullscreen, isFalse);
      expect(fullscreenChangedCalled, isFalse);

      // Wait for timer
      await Future.delayed(const Duration(seconds: 4));

      // Should now be in fullscreen
      expect(controller.isFullscreen, isTrue);
      expect(fullscreenChangedCalled, isTrue);
    });

    test('exitFullscreen should restart timer after exiting', () async {
      // Enter fullscreen first
      controller.enterFullscreen();
      expect(controller.isFullscreen, isTrue);

      // Exit fullscreen
      controller.exitFullscreen();
      expect(controller.isFullscreen, isFalse);

      // Timer should be running again, wait for it
      await Future.delayed(const Duration(seconds: 4));

      // Should be back in fullscreen
      expect(controller.isFullscreen, isTrue);
    });

    test('dispose should cancel timer', () async {
      controller.startFullscreenTimer();

      // Dispose controller
      controller.dispose();

      // Wait to ensure timer doesn't fire
      await Future.delayed(const Duration(seconds: 4));

      // Fullscreen should not have been activated
      expect(fullscreenChangedCalled, isFalse);
    });

    test('dispose should exit fullscreen if active', () {
      // Enter fullscreen
      controller.enterFullscreen();
      expect(controller.isFullscreen, isTrue);

      // Track system UI mode changes
      bool systemUIModeChanged = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'SystemChrome.setEnabledSystemUIMode') {
            systemUIModeChanged = true;
          }
          return null;
        },
      );

      // Dispose should restore system UI mode
      controller.dispose();

      expect(systemUIModeChanged, isTrue);
    });

    test('multiple rapid interactions should handle correctly', () async {
      // Rapid succession of interactions
      controller.restartTimerOnInteraction();
      await Future.delayed(const Duration(milliseconds: 100));

      controller.restartTimerOnInteraction();
      await Future.delayed(const Duration(milliseconds: 100));

      controller.restartTimerOnInteraction();
      await Future.delayed(const Duration(milliseconds: 100));

      // Should not be in fullscreen yet
      expect(controller.isFullscreen, isFalse);

      // Wait for final timer to complete
      await Future.delayed(const Duration(seconds: 4));

      // Should now be in fullscreen (only one timer active)
      expect(controller.isFullscreen, isTrue);
      expect(lastFullscreenValue, isTrue);
    });
  });
}