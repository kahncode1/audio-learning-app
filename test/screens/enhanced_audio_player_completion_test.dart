import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_learning_app/screens/enhanced_audio_player_screen.dart';
import 'package:audio_learning_app/services/audio_player_service_local.dart';
import 'package:audio_learning_app/services/progress_service.dart';
import 'package:audio_learning_app/services/word_timing_service_simplified.dart';
import 'package:audio_learning_app/models/learning_object_v2.dart';
import '../test_data.dart';

// Mock classes
class MockAudioPlayerServiceLocal extends Mock
    implements AudioPlayerServiceLocal {}

class MockProgressService extends Mock implements ProgressService {}

class MockWordTimingServiceSimplified extends Mock
    implements WordTimingServiceSimplified {}

class MockAudioPlayer extends Mock implements AudioPlayer {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

void main() {
  late MockAudioPlayerServiceLocal mockAudioService;
  late MockProgressService mockProgressService;
  late MockWordTimingServiceSimplified mockWordTimingService;
  late MockNavigatorObserver mockNavigatorObserver;
  late LearningObjectV2 testLearningObjectV2;

  setUpAll(() {
    registerFallbackValue(ProcessingState.idle);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(TestData.createTestLearningObjectV2());
  });

  setUp(() {
    mockAudioService = MockAudioPlayerServiceLocal();
    mockProgressService = MockProgressService();
    mockWordTimingService = MockWordTimingServiceSimplified();
    mockNavigatorObserver = MockNavigatorObserver();

    testLearningObjectV2 = TestData.createTestLearningObjectV2(
      id: 'test-id',
      assignmentId: 'assignment-id',
      title: 'Test Learning Object',
      displayText: 'Test content for the learning object',
      totalDurationMs: 60000,
      orderIndex: 1,
      isCompleted: false,
      isInProgress: false,
      currentPositionMs: 0,
    );

    // Setup default mock behaviors
    when(() => mockAudioService.processingStateStream)
        .thenAnswer((_) => Stream.value(ProcessingState.idle));
    when(() => mockAudioService.positionStream)
        .thenAnswer((_) => Stream.value(Duration.zero));
    when(() => mockAudioService.isPlayingStream)
        .thenAnswer((_) => Stream.value(false));
    when(() => mockAudioService.duration)
        .thenReturn(const Duration(seconds: 60));
    when(() => mockAudioService.isPlaying).thenReturn(false);
    when(() => mockAudioService.loadLocalAudio(any())).thenAnswer((_) async {});
    when(() => mockAudioService.play()).thenAnswer((_) async {});
    when(() => mockAudioService.pause()).thenAnswer((_) async {});
    when(() => mockAudioService.seekToPosition(any())).thenAnswer((_) async {});

    // WordTimingServiceSimplified doesn't have loadWordTimings method
    // It loads timing data through constructor or initialization

    when(() => mockProgressService.saveProgress(
          learningObjectId: any(named: 'learningObjectId'),
          positionMs: any(named: 'positionMs'),
          isCompleted: any(named: 'isCompleted'),
          isInProgress: any(named: 'isInProgress'),
        )).thenReturn(null);
  });

  group('Audio Completion Handling', () {
    testWidgets('should listen to processing state stream on init',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: EnhancedAudioPlayerScreen(
              learningObject: testLearningObjectV2,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the processing state stream is being listened to
      verify(() => mockAudioService.processingStateStream)
          .called(greaterThan(0));
    });

    testWidgets('should navigate back when audio completes', (tester) async {
      // Create a stream controller to control the processing state
      final processingStateController = StreamController<ProcessingState>();

      when(() => mockAudioService.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [mockNavigatorObserver],
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderScope(
                      child: EnhancedAudioPlayerScreen(
                        learningObject: testLearningObjectV2,
                        autoPlay: false,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open Player'),
            ),
          ),
        ),
      );

      // Navigate to the audio player screen
      await tester.tap(find.text('Open Player'));
      await tester.pumpAndSettle();

      // Emit completed state
      processingStateController.add(ProcessingState.completed);
      await tester.pumpAndSettle();

      // Verify navigation pop was called
      verify(() => mockNavigatorObserver.didPop(any(), any())).called(1);

      processingStateController.close();
    });

    testWidgets('should mark learning object as completed when audio ends',
        (tester) async {
      final processingStateController = StreamController<ProcessingState>();

      when(() => mockAudioService.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);
      when(() => mockProgressService.saveProgress(
            learningObjectId: testLearningObjectV2.id,
            positionMs: 60000,
            isCompleted: true,
            isInProgress: false,
          )).thenReturn(null);

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: EnhancedAudioPlayerScreen(
              learningObject: testLearningObjectV2,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Emit completed state
      processingStateController.add(ProcessingState.completed);
      await tester.pumpAndSettle();

      // Verify progress was saved with completed status
      verify(() => mockProgressService.saveProgress(
            learningObjectId: testLearningObjectV2.id,
            positionMs: 60000,
            isCompleted: true,
            isInProgress: false,
          )).called(1);

      processingStateController.close();
    });

    testWidgets('should return true when navigating back after completion',
        (tester) async {
      final processingStateController = StreamController<ProcessingState>();
      bool? navigationResult;

      when(() => mockAudioService.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                navigationResult = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderScope(
                      child: EnhancedAudioPlayerScreen(
                        learningObject: testLearningObjectV2,
                        autoPlay: false,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open Player'),
            ),
          ),
        ),
      );

      // Navigate to the audio player screen
      await tester.tap(find.text('Open Player'));
      await tester.pumpAndSettle();

      // Emit completed state
      processingStateController.add(ProcessingState.completed);
      await tester.pumpAndSettle();

      // Verify navigation returned true
      expect(navigationResult, true);

      processingStateController.close();
    });

    testWidgets('should not navigate back for non-completed states',
        (tester) async {
      final processingStateController = StreamController<ProcessingState>();

      when(() => mockAudioService.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [mockNavigatorObserver],
          home: ProviderScope(
            child: EnhancedAudioPlayerScreen(
              learningObject: testLearningObjectV2,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Emit various non-completed states
      processingStateController.add(ProcessingState.idle);
      await tester.pump();
      processingStateController.add(ProcessingState.loading);
      await tester.pump();
      processingStateController.add(ProcessingState.buffering);
      await tester.pump();
      processingStateController.add(ProcessingState.ready);
      await tester.pump();

      // Verify navigation pop was NOT called
      verifyNever(() => mockNavigatorObserver.didPop(any(), any()));

      processingStateController.close();
    });

    testWidgets('should clean up subscription on dispose', (tester) async {
      final processingStateController = StreamController<ProcessingState>();

      when(() => mockAudioService.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: EnhancedAudioPlayerScreen(
              learningObject: testLearningObjectV2,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate away to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Different Screen')),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the stream is no longer being listened to
      expect(processingStateController.hasListener, false);

      processingStateController.close();
    });
  });

  group('Progress Service Integration', () {
    testWidgets('should handle null progress service gracefully',
        (tester) async {
      final processingStateController = StreamController<ProcessingState>();

      when(() => mockAudioService.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: EnhancedAudioPlayerScreen(
              learningObject: testLearningObjectV2,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Emit completed state with null progress service
      processingStateController.add(ProcessingState.completed);
      await tester.pumpAndSettle();

      // Should not throw an error
      expect(tester.takeException(), isNull);

      processingStateController.close();
    });

    testWidgets('should use correct duration when saving progress',
        (tester) async {
      final processingStateController = StreamController<ProcessingState>();
      const testDuration = Duration(minutes: 3, seconds: 30);

      when(() => mockAudioService.processingStateStream)
          .thenAnswer((_) => processingStateController.stream);
      when(() => mockAudioService.duration).thenReturn(testDuration);

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: EnhancedAudioPlayerScreen(
              learningObject: testLearningObjectV2,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Emit completed state
      processingStateController.add(ProcessingState.completed);
      await tester.pumpAndSettle();

      // Verify correct duration was used
      verify(() => mockProgressService.saveProgress(
            learningObjectId: testLearningObjectV2.id,
            positionMs: testDuration.inMilliseconds,
            isCompleted: true,
            isInProgress: false,
          )).called(1);

      processingStateController.close();
    });
  });
}
