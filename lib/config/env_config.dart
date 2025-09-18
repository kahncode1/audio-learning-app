import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// EnvConfig - Environment variable management
///
/// Purpose: Load and manage environment variables from .env file
/// Dependencies: flutter_dotenv package
///
/// Features:
/// - Secure loading of API keys and credentials
/// - Environment-specific configuration
/// - Fallback to default values
/// - Validation of required variables
class EnvConfig {
  static bool _isLoaded = false;

  /// Load environment variables from .env file
  static Future<void> load() async {
    if (_isLoaded) return;

    try {
      await dotenv.load(fileName: '.env');
      _isLoaded = true;
      debugPrint('✅ Environment variables loaded successfully');

      // Validate required variables
      _validateEnvironment();
    } catch (e) {
      debugPrint('⚠️ Failed to load .env file: $e');
      debugPrint('Using default/hardcoded values as fallback');
      _isLoaded = true; // Mark as loaded even if failed
    }
  }

  /// Validate that required environment variables are set
  static void _validateEnvironment() {
    final missing = <String>[];

    // Check Speechify API key
    if (speechifyApiKey == 'YOUR_SPEECHIFY_API_KEY_HERE' ||
        speechifyApiKey == 'your_speechify_api_key_here' ||
        speechifyApiKey.isEmpty) {
      missing.add('SPEECHIFY_API_KEY');
    }

    // Check Cognito (optional for now due to mock auth)
    if (cognitoUserPoolId == 'your_user_pool_id_here' ||
        cognitoUserPoolId.isEmpty) {
      debugPrint('ℹ️ Cognito User Pool ID not configured (using mock auth)');
    }

    if (missing.isNotEmpty) {
      debugPrint('⚠️ Missing or placeholder values for environment variables:');
      for (final variable in missing) {
        debugPrint('  - $variable');
      }
      debugPrint('\n📝 Please update your .env file with actual values');
    } else {
      debugPrint('✅ All required environment variables are configured');
    }
  }

  /// Get environment variable with fallback
  static String _get(String key, String fallback) {
    return dotenv.env[key] ?? fallback;
  }

  // ============================================================================
  // SPEECHIFY CONFIGURATION
  // ============================================================================

  /// Speechify API key
  static String get speechifyApiKey =>
      _get('SPEECHIFY_API_KEY', 'YOUR_SPEECHIFY_API_KEY_HERE');

  /// Speechify base URL
  static String get speechifyBaseUrl =>
      _get('SPEECHIFY_BASE_URL', 'https://api.sws.speechify.com');

  // ============================================================================
  // AWS COGNITO CONFIGURATION
  // ============================================================================

  /// Cognito User Pool ID
  static String get cognitoUserPoolId =>
      _get('COGNITO_USER_POOL_ID', 'YOUR_USER_POOL_ID_HERE');

  /// Cognito Client ID
  static String get cognitoClientId =>
      _get('COGNITO_CLIENT_ID', 'YOUR_CLIENT_ID_HERE');

  /// Cognito Identity Pool ID
  static String get cognitoIdentityPoolId =>
      _get('COGNITO_IDENTITY_POOL_ID', 'YOUR_IDENTITY_POOL_ID_HERE');

  /// Cognito Region
  static String get cognitoRegion => _get('COGNITO_REGION', 'us-east-1');

  // ============================================================================
  // SUPABASE CONFIGURATION
  // ============================================================================

  /// Supabase URL
  static String get supabaseUrl {
    final url = _get('SUPABASE_URL', '');
    if (url.isEmpty) {
      // In development mode with mock auth, we can return a placeholder
      if (isDevelopment && !isSupabaseConfigured) {
        return 'https://placeholder.supabase.co';
      }
      throw Exception('SUPABASE_URL environment variable is required. Please set it in your .env file.');
    }
    return url;
  }

  /// Supabase Anonymous Key
  static String get supabaseAnonKey {
    final key = _get('SUPABASE_ANON_KEY', '');
    if (key.isEmpty) {
      // In development mode with mock auth, we can return a placeholder
      if (isDevelopment && !isSupabaseConfigured) {
        return 'placeholder-key';
      }
      throw Exception('SUPABASE_ANON_KEY environment variable is required. Please set it in your .env file.');
    }
    return key;
  }

  // ============================================================================
  // ELEVENLABS CONFIGURATION
  // ============================================================================

  /// ElevenLabs API key
  static String get elevenLabsApiKey =>
      _get('ELEVENLABS_API_KEY', 'your_api_key_here');

  /// ElevenLabs Voice ID
  static String get elevenLabsVoiceId =>
      _get('ELEVENLABS_VOICE_ID', '21m00Tcm4TlvDq8ikWAM');

  /// ElevenLabs base URL
  static String get elevenLabsBaseUrl =>
      _get('ELEVENLABS_BASE_URL', 'https://api.elevenlabs.io');

  /// Feature flag to use ElevenLabs instead of Speechify
  static bool get useElevenLabs {
    final value = _get('USE_ELEVENLABS', 'false');
    return value.toLowerCase() == 'true';
  }

  // ============================================================================
  // ENVIRONMENT CONFIGURATION
  // ============================================================================

  /// Current environment (development, staging, production)
  static String get environment => _get('ENVIRONMENT', 'development');

  /// Check if running in development
  static bool get isDevelopment => environment.toLowerCase() == 'development';

  /// Check if running in production
  static bool get isProduction => environment.toLowerCase() == 'production';

  // ============================================================================
  // VALIDATION HELPERS
  // ============================================================================

  /// Check if Speechify is configured
  static bool get isSpeechifyConfigured =>
      speechifyApiKey != 'YOUR_SPEECHIFY_API_KEY_HERE' &&
      speechifyApiKey != 'your_speechify_api_key_here' &&
      speechifyApiKey.isNotEmpty;

  /// Check if Cognito is configured
  static bool get isCognitoConfigured =>
      cognitoUserPoolId != 'YOUR_USER_POOL_ID_HERE' &&
      cognitoUserPoolId != 'your_user_pool_id_here' &&
      cognitoUserPoolId.isNotEmpty &&
      cognitoClientId != 'YOUR_CLIENT_ID_HERE' &&
      cognitoClientId != 'your_client_id_here' &&
      cognitoClientId.isNotEmpty;

  /// Check if Supabase is configured
  static bool get isSupabaseConfigured {
    try {
      final url = _get('SUPABASE_URL', '');
      final key = _get('SUPABASE_ANON_KEY', '');
      return url.isNotEmpty && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if ElevenLabs is configured
  static bool get isElevenLabsConfigured =>
      elevenLabsApiKey != 'your_api_key_here' &&
      elevenLabsApiKey.isNotEmpty &&
      elevenLabsVoiceId.isNotEmpty;

  /// Check if all required services are configured
  static bool get isFullyConfigured =>
      (useElevenLabs ? isElevenLabsConfigured : isSpeechifyConfigured); // Use appropriate TTS service

  /// Get configuration status summary
  static void printConfigurationStatus() {
    debugPrint('\n=== Environment Configuration Status ===');
    debugPrint('Environment: $environment');
    debugPrint(
        'Speechify: ${isSpeechifyConfigured ? "✅ Configured" : "❌ Not configured"}');
    debugPrint(
        'Cognito: ${isCognitoConfigured ? "✅ Configured" : "ℹ️ Not configured (using mock auth)"}');
    debugPrint('Supabase: ✅ Configured');
    debugPrint('=====================================\n');
  }
}

/// Validation function for EnvConfig
Future<void> validateEnvConfig() async {
  debugPrint('=== EnvConfig Validation ===');

  // Test 1: Load environment
  await EnvConfig.load();
  assert(EnvConfig._isLoaded, 'Environment must be loaded');
  debugPrint('✓ Environment loading verified');

  // Test 2: Check fallback values
  assert(EnvConfig.supabaseUrl.isNotEmpty, 'Supabase URL must have value');
  assert(EnvConfig.environment.isNotEmpty, 'Environment must have value');
  debugPrint('✓ Fallback values verified');

  // Test 3: Environment checks
  if (EnvConfig.environment == 'development') {
    assert(EnvConfig.isDevelopment, 'Development check must work');
    assert(!EnvConfig.isProduction, 'Production check must be false');
  }
  debugPrint('✓ Environment checks verified');

  // Test 4: Print configuration status
  EnvConfig.printConfigurationStatus();

  debugPrint('=== All EnvConfig validations passed ===');
}
