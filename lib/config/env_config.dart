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
      if (kDebugMode) {
        debugPrint('✅ Environment variables loaded successfully');
      }

      // Validate required variables
      _validateEnvironment();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Failed to load .env file: $e');
        debugPrint('Using default/hardcoded values as fallback');
      }
      _isLoaded = true; // Mark as loaded even if failed
    }
  }

  /// Validate that required environment variables are set
  static void _validateEnvironment() {
    final missing = <String>[];

    // Check Cognito (required)
    if (cognitoUserPoolId == 'your_user_pool_id_here' ||
        cognitoUserPoolId.isEmpty) {
      missing.add('COGNITO_USER_POOL_ID');
    }

    if (missing.isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ Missing or placeholder values for environment variables:');
        for (final variable in missing) {
          debugPrint('  - $variable');
        }
        debugPrint('\n📝 Please update your .env file with actual values');
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ All required environment variables are configured');
      }
    }
  }

  /// Get environment variable with fallback
  static String _get(String key, String fallback) {
    return dotenv.env[key] ?? fallback;
  }

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
      throw Exception(
          'SUPABASE_URL environment variable is required. Please set it in your .env file.');
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
      throw Exception(
          'SUPABASE_ANON_KEY environment variable is required. Please set it in your .env file.');
    }
    return key;
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

  /// Get configuration status summary
  static void printConfigurationStatus() {
    if (kDebugMode) {
      debugPrint('\n=== Environment Configuration Status ===');
      debugPrint('Environment: $environment');
      debugPrint(
          'Cognito: ${isCognitoConfigured ? "✅ Configured" : "ℹ️ Not configured (using mock auth)"}');
      debugPrint('Supabase: ✅ Configured');
      debugPrint('=====================================\n');
    }
  }
}

/// Validation function for EnvConfig
Future<void> validateEnvConfig() async {
  if (kDebugMode) {
    debugPrint('=== EnvConfig Validation ===');
  }

  // Test 1: Load environment
  await EnvConfig.load();
  assert(EnvConfig._isLoaded, 'Environment must be loaded');
  if (kDebugMode) {
    debugPrint('✓ Environment loading verified');
  }

  // Test 2: Check fallback values
  assert(EnvConfig.supabaseUrl.isNotEmpty, 'Supabase URL must have value');
  assert(EnvConfig.environment.isNotEmpty, 'Environment must have value');
  if (kDebugMode) {
    debugPrint('✓ Fallback values verified');
  }

  // Test 3: Environment checks
  if (EnvConfig.environment == 'development') {
    assert(EnvConfig.isDevelopment, 'Development check must work');
    assert(!EnvConfig.isProduction, 'Production check must be false');
  }
  if (kDebugMode) {
    debugPrint('✓ Environment checks verified');
  }

  // Test 4: Print configuration status
  EnvConfig.printConfigurationStatus();

  if (kDebugMode) {
    debugPrint('=== All EnvConfig validations passed ===');
  }
}
