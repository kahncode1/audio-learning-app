import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import '../models/word_timing.dart';
import '../models/learning_object.dart';
import 'speechify_service.dart';
import 'audio/speechify_audio_source.dart';

/// AudioPlayerService - Main audio playback service with advanced controls
///
/// Purpose: Manages audio playback, controls, and synchronization
/// Dependencies:
/// - just_audio: Core audio playback
/// - audio_session: System audio focus management
/// - rxdart: Reactive streams for state management
///
/// Features:
/// - Play/pause with FloatingActionButton support
/// - Skip controls (±30 seconds)
/// - Speed adjustment (0.8x to 2.0x in 0.25x increments)
/// - Position monitoring with time labels
/// - Audio focus and interruption handling
/// - Word timing synchronization for highlighting
class AudioPlayerService {
  static AudioPlayerService? _instance;

  final AudioPlayer _player;
  final SpeechifyService _speechifyService;

  // State streams
  final BehaviorSubject<bool> _isPlayingSubject = BehaviorSubject.seeded(false);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject =
      BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject.seeded(1.0);
  final BehaviorSubject<ProcessingState> _processingStateSubject =
      BehaviorSubject.seeded(ProcessingState.idle);

  // Word timing data
  List<WordTiming> _currentWordTimings = [];
  LearningObject? _currentLearningObject;

  // Playback speed options
  static const List<double> speedOptions = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
  int _currentSpeedIndex = 1; // Default to 1.0x

  // Skip duration
  static const Duration skipDuration = Duration(seconds: 30);

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Private constructor
  AudioPlayerService._()
      : _player = AudioPlayer(),
        _speechifyService = SpeechifyService() {
    _initializePlayer();
  }

  /// Get singleton instance
  static AudioPlayerService get instance {
    _instance ??= AudioPlayerService._();
    return _instance!;
  }

  /// Initialize player and set up listeners
  void _initializePlayer() {
    // Configure audio session
    _configureAudioSession();

    // Listen to player state changes
    _subscriptions.add(
      _player.playingStream.listen((playing) {
        _isPlayingSubject.add(playing);
      }),
    );

    _subscriptions.add(
      _player.positionStream.listen((position) {
        _positionSubject.add(position);
      }),
    );

    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (duration != null) {
          _durationSubject.add(duration);
        }
      }),
    );

    _subscriptions.add(
      _player.processingStateStream.listen((state) {
        _processingStateSubject.add(state);
      }),
    );

    _subscriptions.add(
      _player.speedStream.listen((speed) {
        _speedSubject.add(speed);
      }),
    );
  }

  /// Configure audio session for background playback
  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // Handle interruptions
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Lower volume
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Pause playback
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Restore volume
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Resume if we should
            if (!_isPlayingSubject.value) {
              play();
            }
            break;
        }
      }
    });
  }

  /// Load audio for a learning object
  Future<void> loadLearningObject(LearningObject learningObject) async {
    try {
      _currentLearningObject = learningObject;

      // Generate audio with timings
      final result = await _speechifyService.generateAudioWithTimings(
        content: learningObject.plainText ?? '',
        isSSML: (learningObject.plainText ?? '').trim().startsWith('<speak>'),
      );

      // Store word timings
      _currentWordTimings = result.wordTimings;

      // Create audio source from base64 data
      // For now, we need to handle the base64 audio data
      // This will require updating SpeechifyAudioSource to handle base64
      final audioSource = await createSpeechifyAudioSource(result.audioData);

      // Set the audio source
      await _player.setAudioSource(audioSource);

      // Restore previous position if available
      if (learningObject.currentPositionMs > 0) {
        await seekToPosition(
            Duration(milliseconds: learningObject.currentPositionMs));
      }

      debugPrint('Audio loaded successfully for: ${learningObject.title}');
    } catch (e) {
      debugPrint('Error loading audio: $e');
      throw Exception('Failed to load audio: $e');
    }
  }

  /// Play audio
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      throw Exception('Failed to play audio: $e');
    }
  }

  /// Pause audio
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlayingSubject.value) {
      await pause();
    } else {
      await play();
    }
  }

  /// Skip forward by 30 seconds
  Future<void> skipForward() async {
    final newPosition = _positionSubject.value + skipDuration;
    final duration = _durationSubject.value;

    if (newPosition < duration) {
      await seekToPosition(newPosition);
    } else {
      await seekToPosition(duration);
    }
  }

  /// Skip backward by 30 seconds
  Future<void> skipBackward() async {
    final newPosition = _positionSubject.value - skipDuration;

    if (newPosition > Duration.zero) {
      await seekToPosition(newPosition);
    } else {
      await seekToPosition(Duration.zero);
    }
  }

  /// Seek to specific position
  Future<void> seekToPosition(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  /// Cycle through playback speeds
  Future<void> cycleSpeed() async {
    _currentSpeedIndex = (_currentSpeedIndex + 1) % speedOptions.length;
    final newSpeed = speedOptions[_currentSpeedIndex];
    await setSpeed(newSpeed);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);

      // Find the index for this speed
      final index = speedOptions.indexOf(speed);
      if (index != -1) {
        _currentSpeedIndex = index;
      }
    } catch (e) {
      debugPrint('Error setting speed: $e');
    }
  }

  /// Get current word index based on position
  int? getCurrentWordIndex() {
    if (_currentWordTimings.isEmpty) return null;

    final positionMs = _positionSubject.value.inMilliseconds;

    // Binary search for current word
    int left = 0;
    int right = _currentWordTimings.length - 1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final timing = _currentWordTimings[mid];

      if (positionMs >= timing.startMs && positionMs <= timing.endMs) {
        return mid;
      } else if (positionMs < timing.startMs) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    // If not found, return the closest word
    if (left < _currentWordTimings.length) {
      return left;
    }

    return null;
  }

  /// Get current sentence index based on position
  int? getCurrentSentenceIndex() {
    final wordIndex = getCurrentWordIndex();
    if (wordIndex == null || _currentWordTimings.isEmpty) return null;

    return _currentWordTimings[wordIndex].sentenceIndex;
  }

  /// Seek to a specific word
  Future<void> seekToWord(int wordIndex) async {
    if (wordIndex < 0 || wordIndex >= _currentWordTimings.length) return;

    final timing = _currentWordTimings[wordIndex];
    await seekToPosition(Duration(milliseconds: timing.startMs));
  }

  // Stream getters
  Stream<bool> get isPlayingStream => _isPlayingSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration> get durationStream => _durationSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;
  Stream<ProcessingState> get processingStateStream =>
      _processingStateSubject.stream;

  // Current state getters
  bool get isPlaying => _isPlayingSubject.value;
  Duration get position => _positionSubject.value;
  Duration get duration => _durationSubject.value;
  double get speed => _speedSubject.value;
  ProcessingState get processingState => _processingStateSubject.value;
  List<WordTiming> get wordTimings => _currentWordTimings;
  LearningObject? get currentLearningObject => _currentLearningObject;

  /// Clean up resources
  void dispose() {
    // Cancel subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    // Dispose subjects
    _isPlayingSubject.close();
    _positionSubject.close();
    _durationSubject.close();
    _speedSubject.close();
    _processingStateSubject.close();

    // Dispose player
    _player.dispose();

    // Clear instance
    _instance = null;
  }
}

/// Validation function for AudioPlayerService
void validateAudioPlayerService() {
  debugPrint('=== AudioPlayerService Validation ===');

  // Test 1: Singleton pattern
  final instance1 = AudioPlayerService.instance;
  final instance2 = AudioPlayerService.instance;
  assert(identical(instance1, instance2),
      'AudioPlayerService must be a singleton');
  debugPrint('✓ Singleton pattern verified');

  // Test 2: Speed options
  assert(
      AudioPlayerService.speedOptions.length == 6, 'Must have 6 speed options');
  assert(
      AudioPlayerService.speedOptions.contains(1.0), 'Must include 1.0x speed');
  debugPrint('✓ Speed options verified');

  // Test 3: Skip duration
  assert(AudioPlayerService.skipDuration == const Duration(seconds: 30),
      'Skip must be 30 seconds');
  debugPrint('✓ Skip duration verified');

  // Test 4: Initial state
  assert(!instance1.isPlaying, 'Should not be playing initially');
  assert(instance1.position == Duration.zero, 'Position should start at zero');
  assert(instance1.speed == 1.0, 'Speed should default to 1.0x');
  debugPrint('✓ Initial state verified');

  // Test 5: Word index calculation with empty timings
  final wordIndex = instance1.getCurrentWordIndex();
  assert(wordIndex == null, 'Should return null with no timings');
  debugPrint('✓ Empty word timing handling verified');

  debugPrint('=== All AudioPlayerService validations passed ===');
}
