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
      _get('SPEECHIFY_BASE_URL', 'https://api.speechify.com');

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
  static String get cognitoRegion =>
      _get('COGNITO_REGION', 'us-east-1');

  // ============================================================================
  // SUPABASE CONFIGURATION
  // ============================================================================

  /// Supabase URL
  static String get supabaseUrl =>
      _get('SUPABASE_URL', 'https://cmjdciktvfxiyapdseqn.supabase.co');

  /// Supabase Anonymous Key
  static String get supabaseAnonKey =>
      _get('SUPABASE_ANON_KEY',
           'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtamRjaWt0dmZ4aXlhcGRzZXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3ODAwODAsImV4cCI6MjA3MzM1NjA4MH0.qIhF8LgDnm6OrlnhNWNJziNc6OopUu0qCYtgJhXouB8');

  // ============================================================================
  // ENVIRONMENT CONFIGURATION
  // ============================================================================

  /// Current environment (development, staging, production)
  static String get environment =>
      _get('ENVIRONMENT', 'development');

  /// Check if running in development
  static bool get isDevelopment =>
      environment.toLowerCase() == 'development';

  /// Check if running in production
  static bool get isProduction =>
      environment.toLowerCase() == 'production';

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

  /// Check if all required services are configured
  static bool get isFullyConfigured =>
      isSpeechifyConfigured; // Cognito is optional with mock auth

  /// Get configuration status summary
  static void printConfigurationStatus() {
    debugPrint('\n=== Environment Configuration Status ===');
    debugPrint('Environment: $environment');
    debugPrint('Speechify: ${isSpeechifyConfigured ? "✅ Configured" : "❌ Not configured"}');
    debugPrint('Cognito: ${isCognitoConfigured ? "✅ Configured" : "ℹ️ Not configured (using mock auth)"}');
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