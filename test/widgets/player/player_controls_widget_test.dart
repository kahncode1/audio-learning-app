import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_learning_app/widgets/player/player_controls_widget.dart';
import 'package:audio_learning_app/services/audio_player_service_local.dart';
import 'package:audio_learning_app/services/progress_service.dart';

// Mock classes
class MockAudioPlayerServiceLocal extends Mock implements AudioPlayerServiceLocal {}
class MockProgressService extends Mock implements ProgressService {}

void main() {
  group('PlayerControlsWidget', () {
    late MockAudioPlayerServiceLocal mockAudioService;
    late MockProgressService mockProgressService;

    setUp(() {
      mockAudioService = MockAudioPlayerServiceLocal();
      mockProgressService = MockProgressService();

      // Set up default stream values
      when(() => mockAudioService.isPlayingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioService.speedStream).thenAnswer((_) => Stream.value(1.0));
      when(() => mockProgressService.fontSizeIndexStream).thenAnswer((_) => Stream.value(1));
      when(() => mockProgressService.currentFontSizeName).thenReturn('Medium');
    });

    Widget createTestWidget({VoidCallback? onInteraction}) {
      return MaterialApp(
        home: Scaffold(
          body: ProviderScope(
            child: PlayerControlsWidget(
              onInteraction: onInteraction,
            ),
          ),
        ),
      );
    }

    testWidgets('should display all control buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for speed control button
      expect(find.text('1.0x'), findsOneWidget);

      // Check for skip backward button
      expect(find.byIcon(Icons.replay_30), findsOneWidget);

      // Check for play/pause button
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Check for skip forward button
      expect(find.byIcon(Icons.forward_30), findsOneWidget);

      // Check for font size control button
      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets('should toggle play/pause button based on playing state', (WidgetTester tester) async {
      // Start with not playing
      when(() => mockAudioService.isPlayingStream).thenAnswer((_) => Stream.value(false));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);

      // Update to playing state
      when(() => mockAudioService.isPlayingStream).thenAnswer((_) => Stream.value(true));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('should display correct speed value', (WidgetTester tester) async {
      when(() => mockAudioService.speedStream).thenAnswer((_) => Stream.value(1.5));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('1.5x'), findsOneWidget);
    });

    testWidgets('should call onInteraction when play button is tapped', (WidgetTester tester) async {
      bool interactionCalled = false;

      await tester.pumpWidget(createTestWidget(
        onInteraction: () {
          interactionCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(interactionCalled, isTrue);
    });

    testWidgets('should call onInteraction when skip forward is tapped', (WidgetTester tester) async {
      bool interactionCalled = false;

      await tester.pumpWidget(createTestWidget(
        onInteraction: () {
          interactionCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.forward_30));
      await tester.pumpAndSettle();

      expect(interactionCalled, isTrue);
    });

    testWidgets('should call onInteraction when skip backward is tapped', (WidgetTester tester) async {
      bool interactionCalled = false;

      await tester.pumpWidget(createTestWidget(
        onInteraction: () {
          interactionCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.replay_30));
      await tester.pumpAndSettle();

      expect(interactionCalled, isTrue);
    });

    testWidgets('should display correct font size name', (WidgetTester tester) async {
      when(() => mockProgressService.currentFontSizeName).thenReturn('Large');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Large'), findsOneWidget);
    });

    testWidgets('should have correct button styles in light mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: ProviderScope(
              child: PlayerControlsWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find speed control button
      final speedButton = find.widgetWithText(TextButton, '1.0x');
      expect(speedButton, findsOneWidget);

      // Check that the button exists and has proper styling
      final TextButton button = tester.widget(speedButton);
      expect(button.style, isNotNull);
    });

    testWidgets('should have correct button styles in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: ProviderScope(
              child: PlayerControlsWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find speed control button
      final speedButton = find.widgetWithText(TextButton, '1.0x');
      expect(speedButton, findsOneWidget);

      // Check that the button exists and has proper styling
      final TextButton button = tester.widget(speedButton);
      expect(button.style, isNotNull);
    });

    testWidgets('should have correct tooltips on buttons', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check skip backward tooltip
      final skipBackward = find.byIcon(Icons.replay_30);
      final IconButton skipBackwardButton = tester.widget(skipBackward);
      expect(skipBackwardButton.tooltip, 'Skip back 30s (←)');

      // Check skip forward tooltip
      final skipForward = find.byIcon(Icons.forward_30);
      final IconButton skipForwardButton = tester.widget(skipForward);
      expect(skipForwardButton.tooltip, 'Skip forward 30s (→)');

      // Check play/pause tooltip
      final playPause = find.byType(FloatingActionButton);
      final FloatingActionButton playPauseButton = tester.widget(playPause);
      expect(playPauseButton.tooltip, 'Play/Pause (Space)');
    });

    testWidgets('should maintain correct padding', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final padding = find.byType(Padding).first;
      final Padding paddingWidget = tester.widget(padding);

      expect(paddingWidget.padding, const EdgeInsets.fromLTRB(16, 0, 16, 20));
    });

    testWidgets('should arrange controls in correct order', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final row = find.byType(Row).first;
      final Row rowWidget = tester.widget(row);

      expect(rowWidget.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
      expect(rowWidget.children.length, 5); // 5 controls total
    });
  });
}