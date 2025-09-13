# /implementations/audio-service.dart

```dart
/// Audio Service - Speechify API Integration and Stream Management
/// 
/// Handles all audio operations including:
/// - Speechify API text-to-speech generation
/// - Custom StreamAudioSource for audio streaming
/// - Connection pooling and retry logic
/// - Buffer management for smooth playback

import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class SpeechifyService {
  static const String _baseUrl = 'https://api.speechify.com/v1';
  static const int _maxRetries = 3;
  static const List<int> _retryDelays = [1000, 2000, 4000]; // milliseconds
  
  final Dio _dio;
  final Logger _logger = Logger();
  
  SpeechifyService({Dio? dio}) : _dio = dio ?? _createDefaultDio();
  
  static Dio _createDefaultDio() {
    return Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer ${Env.speechifyApiKey}',
        'Content-Type': 'application/json',
      },
    ))
      ..interceptors.addAll([
        AuthInterceptor(),
        CacheInterceptor(),
        RetryInterceptor(maxRetries: _maxRetries, retryDelays: _retryDelays),
        if (kDebugMode) LoggingInterceptor(),
      ]);
  }
  
  /// Generate audio stream from SSML content
  Future<String?> generateAudioStream(
    String ssmlContent, {
    double speed = 1.5,
    String voice = 'professional_male_v2',
  }) async {
    try {
      final response = await _dio.post(
        '/audio/generate',
        data: {
          'ssml': ssmlContent,
          'voice': voice,
          'speed': speed,
          'format': 'mp3',
          'sample_rate': 44100,
          'include_word_timings': true,
        },
      );
      
      if (response.statusCode == 200) {
        return response.data['audio_url'];
      }
      
      _logger.error('Failed to generate audio: ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.error('Error generating audio stream: $e');
      return null;
    }
  }
  
  /// Fetch word timings for content
  Future<List<WordTiming>?> fetchWordTimings(String contentId) async {
    try {
      final response = await _dio.get('/timings/$contentId');
      
      if (response.statusCode == 200) {
        final timingsData = response.data['timings'] as List;
        return timingsData
            .map((json) => WordTiming.fromJson(json))
            .toList();
      }
      
      return null;
    } catch (e) {
      _logger.error('Error fetching word timings: $e');
      return null;
    }
  }
  
  void dispose() {
    _dio.close();
  }
}

/// Custom StreamAudioSource Implementation for Speechify
class SpeechifyAudioSource extends StreamAudioSource {
  final String contentUrl;
  final Dio _dio;
  final BehaviorSubject<double> bufferProgressSubject = BehaviorSubject.seeded(0.0);
  
  SpeechifyAudioSource({
    required this.contentUrl,
    Dio? dio,
  }) : _dio = dio ?? DioProvider.instance;
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final headers = <String, String>{};
    if (start != null || end != null) {
      headers['Range'] = 'bytes=${start ?? 0}-${end ?? ''}';
    }
    
    int retryCount = 0;
    while (retryCount < 3) {
      try {
        final response = await _dio.get<ResponseBody>(
          contentUrl,
          options: Options(
            headers: headers,
            responseType: ResponseType.stream,
          ),
        );
        
        final stream = response.data!.stream;
        final contentLength = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        );
        
        // Monitor buffer progress
        int bytesReceived = 0;
        final transformedStream = stream.transform(
          StreamTransformer<Uint8List, Uint8List>.fromHandlers(
            handleData: (data, sink) {
              bytesReceived += data.length;
              if (contentLength != null && contentLength > 0) {
                bufferProgressSubject.add(bytesReceived / contentLength);
              }
              sink.add(data);
            },
          ),
        );
        
        return StreamAudioResponse(
          sourceLength: contentLength,
          contentLength: contentLength ?? 0,
          offset: start ?? 0,
          stream: transformedStream,
          contentType: response.headers.value(Headers.contentTypeHeader) ?? 'audio/mpeg',
        );
      } catch (e) {
        retryCount++;
        if (retryCount >= 3) {
          throw AudioStreamException('Failed to load audio after 3 attempts', originalError: e);
        }
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
    throw AudioStreamException('Failed to create audio stream');
  }
  
  @override
  Future<void> close() async {
    await bufferProgressSubject.close();
    super.close();
  }
}

/// Audio Player Service - Manages playback and state
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final BehaviorSubject<Duration> _positionSubject = BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<bool> _isPlayingSubject = BehaviorSubject.seeded(false);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject.seeded(1.5);
  
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<bool> get isPlayingStream => _isPlayingSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;
  
  Duration get currentPosition => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;
  
  Future<void> initialize() async {
    // Set up position updates
    _positionSubscription = _player.positionStream.listen((position) {
      _positionSubject.add(position);
    });
    
    // Set up state updates
    _stateSubscription = _player.playerStateStream.listen((state) {
      _isPlayingSubject.add(state.playing);
    });
    
    // Configure audio session for speech
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }
  
  Future<void> loadAudioSource(
    String contentUrl, {
    Duration? initialPosition,
    double speed = 1.5,
  }) async {
    final audioSource = SpeechifyAudioSource(contentUrl: contentUrl);
    
    await _player.setAudioSource(
      audioSource,
      initialPosition: initialPosition,
    );
    
    await _player.setSpeed(speed);
    _speedSubject.add(speed);
  }
  
  Future<void> play() async {
    await _player.play();
  }
  
  Future<void> pause() async {
    await _player.pause();
  }
  
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }
  
  Future<void> skipForward(int seconds) async {
    final newPosition = _player.position + Duration(seconds: seconds);
    await seek(newPosition.clamp(
      Duration.zero,
      _player.duration ?? Duration.zero,
    ));
  }
  
  Future<void> skipBackward(int seconds) async {
    final newPosition = _player.position - Duration(seconds: seconds);
    await seek(newPosition.clamp(
      Duration.zero,
      _player.duration ?? Duration.zero,
    ));
  }
  
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _speedSubject.add(speed);
  }
  
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    _positionSubject.close();
    _isPlayingSubject.close();
    _speedSubject.close();
    _player.dispose();
  }
}

// Validation function
void main() async {
  print('🔧 Testing Audio Services...\n');
  
  final List<String> validationFailures = [];
  int totalTests = 0;
  
  // Test 1: SpeechifyService initialization
  totalTests++;
  try {
    final service = SpeechifyService();
    print('✓ SpeechifyService initialized successfully');
  } catch (e) {
    validationFailures.add('SpeechifyService initialization failed: $e');
  }
  
  // Test 2: Audio stream request
  totalTests++;
  try {
    final service = SpeechifyService();
    const testContent = '<speak>Hello, this is a test of the audio service.</speak>';
    final url = await service.generateAudioStream(testContent);
    
    if (url == null) {
      validationFailures.add('Audio stream generation returned null');
    } else {
      print('✓ Audio stream URL generated successfully');
    }
  } catch (e) {
    validationFailures.add('Audio stream generation failed: $e');
  }
  
  // Test 3: StreamAudioSource creation
  totalTests++;
  try {
    final source = SpeechifyAudioSource(
      contentUrl: 'https://test.url/audio.mp3',
    );
    print('✓ StreamAudioSource created successfully');
  } catch (e) {
    validationFailures.add('StreamAudioSource creation failed: $e');
  }
  
  // Test 4: AudioPlayerService initialization
  totalTests++;
  try {
    final playerService = AudioPlayerService();
    await playerService.initialize();
    print('✓ AudioPlayerService initialized successfully');
  } catch (e) {
    validationFailures.add('AudioPlayerService initialization failed: $e');
  }
  
  // Test 5: Speed control
  totalTests++;
  try {
    final playerService = AudioPlayerService();
    await playerService.initialize();
    await playerService.setSpeed(1.75);
    print('✓ Playback speed control working');
  } catch (e) {
    validationFailures.add('Speed control failed: $e');
  }
  
  // Final validation results
  print('\n' + '=' * 50);
  if (validationFailures.isNotEmpty) {
    print('❌ VALIDATION FAILED - ${validationFailures.length} of $totalTests tests failed:\n');
    for (final failure in validationFailures) {
      print('  • $failure');
    }
    exit(1);
  } else {
    print('✅ VALIDATION PASSED - All $totalTests tests produced expected results');
    print('Audio services are ready for integration');
    exit(0);
  }
}
```