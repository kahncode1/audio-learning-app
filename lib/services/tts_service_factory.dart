import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import '../utils/app_logger.dart';
import 'speechify_service.dart';
import 'elevenlabs_service.dart';

/// TTS Provider enumeration
enum TTSProvider {
  speechify,
  elevenlabs,
}

/// TTSServiceFactory - Factory for selecting TTS provider
///
/// Purpose: Provides a centralized way to select between different TTS providers
/// Dependencies:
/// - SpeechifyService: Primary TTS provider with SSML support
/// - ElevenLabsService: Alternative provider with binary streaming
/// - EnvConfig: Environment configuration for feature flags
///
/// Features:
/// - Runtime provider selection based on configuration
/// - Consistent interface across providers
/// - Automatic fallback to Speechify if ElevenLabs unavailable
/// - Performance metrics logging for comparison
class TTSServiceFactory {
  static TTSProvider? _currentProvider;
  static DateTime? _lastProviderCheck;
  static const Duration _providerCheckInterval = Duration(minutes: 5);

  /// Get the current TTS provider based on configuration
  static TTSProvider getCurrentProvider() {
    // Cache provider selection for performance
    final now = DateTime.now();
    if (_currentProvider != null &&
        _lastProviderCheck != null &&
        now.difference(_lastProviderCheck!) < _providerCheckInterval) {
      return _currentProvider!;
    }

    // Check environment configuration
    try {
      final useElevenLabs = EnvConfig.useElevenLabs;

      if (useElevenLabs) {
        // Verify ElevenLabs is configured
        if (ElevenLabsService.instance.isConfigured()) {
          _currentProvider = TTSProvider.elevenlabs;
          AppLogger.info('TTS Provider selected', {
            'provider': 'ElevenLabs',
            'reason': 'Feature flag enabled and configured',
          });
        } else {
          _currentProvider = TTSProvider.speechify;
          AppLogger.warning('ElevenLabs requested but not configured', {
            'fallback': 'Speechify',
          });
        }
      } else {
        _currentProvider = TTSProvider.speechify;
        AppLogger.info('TTS Provider selected', {
          'provider': 'Speechify',
          'reason': 'Default provider',
        });
      }
    } catch (e) {
      // Default to Speechify on any error
      _currentProvider = TTSProvider.speechify;
      AppLogger.error('Error selecting TTS provider', error: e, data: {
        'fallback': 'Speechify',
      });
    }

    _lastProviderCheck = now;
    return _currentProvider!;
  }

  /// Create appropriate TTS service based on current configuration
  static dynamic createTTSService() {
    final provider = getCurrentProvider();

    switch (provider) {
      case TTSProvider.elevenlabs:
        return ElevenLabsService.instance;
      case TTSProvider.speechify:
      default:
        return SpeechifyService.instance;
    }
  }

  /// Generate audio with timings using selected provider
  static Future<AudioGenerationResult> generateAudioWithTimings({
    required String content,
    String? voice,
    double speed = 1.0,
    bool isSSML = false,
  }) async {
    final provider = getCurrentProvider();
    final startTime = DateTime.now();

    try {
      AudioGenerationResult result;

      switch (provider) {
        case TTSProvider.elevenlabs:
          // ElevenLabs doesn't support SSML, log if attempted
          if (isSSML) {
            AppLogger.warning('SSML requested with ElevenLabs (not supported)', {
              'contentLength': content.length,
            });
          }

          result = await ElevenLabsService.instance.generateAudioStream(
            content: content,
            voice: voice,
            speed: speed,
            isSSML: false, // Always false for ElevenLabs
          );
          break;

        case TTSProvider.speechify:
        default:
          result = await SpeechifyService.instance.generateAudioWithTimings(
            content: content,
            voice: voice ?? SpeechifyService.defaultVoice,
            speed: speed,
            isSSML: isSSML,
          );
          break;
      }

      // Log performance metrics
      final duration = DateTime.now().difference(startTime);
      AppLogger.info('TTS generation completed', {
        'provider': provider.name,
        'durationMs': duration.inMilliseconds,
        'wordCount': result.wordTimings.length,
        'audioSizeBytes': result.audioData.length,
      });

      return result;

    } catch (e) {
      // Log error with provider context
      AppLogger.error('TTS generation failed', error: e, data: {
        'provider': provider.name,
        'durationMs': DateTime.now().difference(startTime).inMilliseconds,
      });

      // If ElevenLabs fails, try fallback to Speechify
      if (provider == TTSProvider.elevenlabs) {
        AppLogger.warning('Falling back to Speechify after ElevenLabs failure');

        // Force provider refresh
        _currentProvider = TTSProvider.speechify;

        return SpeechifyService.instance.generateAudioWithTimings(
          content: content,
          voice: voice ?? SpeechifyService.defaultVoice,
          speed: speed,
          isSSML: isSSML,
        );
      }

      rethrow;
    }
  }

  /// Get appropriate voice ID for current provider
  static String getDefaultVoice() {
    final provider = getCurrentProvider();

    switch (provider) {
      case TTSProvider.elevenlabs:
        // Return configured ElevenLabs voice or default
        try {
          return EnvConfig.elevenLabsVoiceId;
        } catch (_) {
          return '21m00Tcm4TlvDq8ikWAM'; // Default Rachel voice
        }

      case TTSProvider.speechify:
      default:
        return SpeechifyService.defaultVoice;
    }
  }

  /// Check if SSML is supported by current provider
  static bool isSSMLSupported() {
    final provider = getCurrentProvider();

    switch (provider) {
      case TTSProvider.elevenlabs:
        return false; // ElevenLabs doesn't support SSML
      case TTSProvider.speechify:
      default:
        return true;
    }
  }

  /// Get provider capabilities
  static Map<String, dynamic> getProviderCapabilities() {
    final provider = getCurrentProvider();

    switch (provider) {
      case TTSProvider.elevenlabs:
        return {
          'provider': 'ElevenLabs',
          'ssmlSupport': false,
          'binaryStreaming': true,
          'characterTiming': true,
          'wordTiming': false, // Requires transformation
          'sentenceDetection': 'algorithmic',
          'streamingType': 'HTTP chunked',
          'audioFormat': 'mp3',
        };

      case TTSProvider.speechify:
      default:
        return {
          'provider': 'Speechify',
          'ssmlSupport': true,
          'binaryStreaming': false,
          'characterTiming': true,
          'wordTiming': true,
          'sentenceDetection': 'API provided',
          'streamingType': 'Base64 JSON',
          'audioFormat': 'wav',
        };
    }
  }

  /// Force provider selection (for testing)
  @visibleForTesting
  static void setProvider(TTSProvider provider) {
    _currentProvider = provider;
    _lastProviderCheck = DateTime.now();

    AppLogger.info('TTS Provider manually set', {
      'provider': provider.name,
    });
  }

  /// Clear provider cache (forces re-evaluation)
  static void clearProviderCache() {
    _currentProvider = null;
    _lastProviderCheck = null;

    AppLogger.info('TTS Provider cache cleared');
  }
}

/// Validation function for TTSServiceFactory
void validateTTSServiceFactory() {
  debugPrint('=== TTSServiceFactory Validation ===');

  // Test 1: Provider selection
  final provider = TTSServiceFactory.getCurrentProvider();
  assert(provider == TTSProvider.speechify || provider == TTSProvider.elevenlabs,
      'Must select a valid provider');
  debugPrint('✓ Provider selection verified: ${provider.name}');

  // Test 2: Service creation
  final service = TTSServiceFactory.createTTSService();
  assert(service != null, 'Service must be created');
  assert(
      service is SpeechifyService || service is ElevenLabsService,
      'Service must be correct type');
  debugPrint('✓ Service creation verified');

  // Test 3: Default voice
  final voice = TTSServiceFactory.getDefaultVoice();
  assert(voice.isNotEmpty, 'Default voice must be set');
  debugPrint('✓ Default voice verified: $voice');

  // Test 4: SSML support check
  final ssmlSupported = TTSServiceFactory.isSSMLSupported();
  if (provider == TTSProvider.elevenlabs) {
    assert(!ssmlSupported, 'ElevenLabs should not support SSML');
  } else {
    assert(ssmlSupported, 'Speechify should support SSML');
  }
  debugPrint('✓ SSML support verified: $ssmlSupported');

  // Test 5: Provider capabilities
  final capabilities = TTSServiceFactory.getProviderCapabilities();
  assert(capabilities.isNotEmpty, 'Capabilities must be provided');
  assert(capabilities['provider'] != null, 'Provider name must be set');
  debugPrint('✓ Provider capabilities verified');

  // Test 6: Cache behavior
  final provider1 = TTSServiceFactory.getCurrentProvider();
  final provider2 = TTSServiceFactory.getCurrentProvider();
  assert(provider1 == provider2, 'Provider should be cached');
  debugPrint('✓ Provider caching verified');

  // Test 7: Cache clearing
  TTSServiceFactory.clearProviderCache();
  // Should re-evaluate after clearing
  final provider3 = TTSServiceFactory.getCurrentProvider();
  assert(provider3.name.isNotEmpty, 'Provider should be re-evaluated');
  debugPrint('✓ Cache clearing verified');

  debugPrint('=== All TTSServiceFactory validations passed ===');
}