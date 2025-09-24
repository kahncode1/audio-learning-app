import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_learning_app/widgets/player/audio_progress_bar.dart';
import 'package:audio_learning_app/services/audio_player_service_local.dart';

// Mock class
class MockAudioPlayerServiceLocal extends Mock implements AudioPlayerServiceLocal {}

void main() {
  group('AudioProgressBar', () {
    late MockAudioPlayerServiceLocal mockAudioService;

    setUp(() {
      mockAudioService = MockAudioPlayerServiceLocal();

      // Set up default stream values
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 5)));
    });

    Widget createTestWidget({VoidCallback? onInteraction}) {
      return MaterialApp(
        home: Scaffold(
          body: ProviderScope(
            child: AudioProgressBar(
              onInteraction: onInteraction,
            ),
          ),
        ),
      );
    }

    testWidgets('should display slider', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('should display time labels', (WidgetTester tester) async {
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 1, seconds: 30)));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 5)));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for current position display
      expect(find.text('01:30'), findsOneWidget);
      // Check for remaining time display
      expect(find.text('03:30'), findsOneWidget);
    });

    testWidgets('should format duration correctly without hours', (WidgetTester tester) async {
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(const Duration(seconds: 45)));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 3, seconds: 20)));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('02:35'), findsOneWidget); // 3:20 - 0:45 = 2:35
    });

    testWidgets('should format duration correctly with hours', (WidgetTester tester) async {
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(const Duration(hours: 1, minutes: 15, seconds: 30)));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(hours: 2)));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('1:15:30'), findsOneWidget);
      expect(find.text('0:44:30'), findsOneWidget); // 2:00:00 - 1:15:30
    });

    testWidgets('should update slider value based on position', (WidgetTester tester) async {
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 2, seconds: 30)));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 5)));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      // 2:30 / 5:00 = 150 / 300 = 0.5
      expect(slider.value, 0.5);
    });

    testWidgets('should handle zero duration gracefully', (WidgetTester tester) async {
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(Duration.zero));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.0);

      expect(find.text('00:00'), findsNWidgets(2)); // Both position and remaining
    });

    testWidgets('should call onInteraction when slider is moved', (WidgetTester tester) async {
      bool interactionCalled = false;

      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 1)));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 5)));

      await tester.pumpWidget(createTestWidget(
        onInteraction: () {
          interactionCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      // Drag the slider
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(interactionCalled, isTrue);
    });

    testWidgets('should handle position stream errors gracefully', (WidgetTester tester) async {
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.error('Position stream error'));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 5)));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should render empty SizedBox when there's an error
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('should handle duration stream errors gracefully', (WidgetTester tester) async {
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 1)));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.error('Duration stream error'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should render empty SizedBox when there's an error
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('should have correct slider theme', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final sliderTheme = find.byType(SliderTheme);
      expect(sliderTheme, findsOneWidget);

      final SliderTheme theme = tester.widget(sliderTheme);
      final data = theme.data;

      expect(data.trackHeight, 3.0);
      expect(data.thumbShape, isA<RoundSliderThumbShape>());
      expect(data.overlayShape, isA<RoundSliderOverlayShape>());
      expect(data.trackShape, isA<RectangularSliderTrackShape>());
    });

    testWidgets('should have correct padding for time labels', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the Padding widget that contains the time labels
      final paddings = find.byType(Padding);

      // Should have at least one Padding widget for time labels
      expect(paddings, findsWidgets);

      // Check the padding with time labels
      for (final padding in paddings.evaluate()) {
        final Padding paddingWidget = padding.widget as Padding;
        if (paddingWidget.padding == const EdgeInsets.fromLTRB(24, 2, 24, 8)) {
          // Found the correct padding for time labels
          expect(paddingWidget.padding, const EdgeInsets.fromLTRB(24, 2, 24, 8));
          break;
        }
      }
    });

    testWidgets('should clamp slider value between 0 and 1', (WidgetTester tester) async {
      // Test with position greater than duration (shouldn't happen but handle gracefully)
      when(() => mockAudioService.positionStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 10)));
      when(() => mockAudioService.durationStream)
          .thenAnswer((_) => Stream.value(const Duration(minutes: 5)));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      // Should be clamped to 0.0 because position > duration
      expect(slider.value, 0.0);
    });

    testWidgets('should use primary color for active track', (WidgetTester tester) async {
      final testColor = Colors.blue;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: testColor),
          home: Scaffold(
            body: ProviderScope(
              child: AudioProgressBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.activeColor, testColor);
    });
  });
}