import 'env_config.dart';

/// Application Configuration
///
/// Purpose: Centralized configuration for AWS Cognito and Supabase
/// Dependencies: EnvConfig for environment variables
///
/// Usage:
///   final config = AppConfig();
///   final userPoolId = config.cognitoUserPoolId;
///
/// This class now uses environment variables loaded from .env file
/// Falls back to hardcoded values if environment variables are not set

class AppConfig {
  // Singleton pattern
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  // ============================================================================
  // AWS COGNITO CONFIGURATION
  // ============================================================================
  // After creating your Cognito User Pool, update these values:

  /// Your Cognito User Pool ID (from environment or fallback)
  /// Format: {region}_{randomString}
  /// Example: 'us-east-1_AbCdEfGhI'
  static String get cognitoUserPoolId => EnvConfig.cognitoUserPoolId;

  /// Your Cognito App Client ID (from environment or fallback)
  /// Found in: User Pool → App Integration → App clients
  /// Example: '1234567890abcdefghijklmnop'
  static String get cognitoClientId => EnvConfig.cognitoClientId;

  /// Your Cognito Identity Pool ID (from environment or fallback)
  /// Format: {region}:{uuid}
  /// Example: 'us-east-1:12345678-1234-1234-1234-123456789012'
  static String get cognitoIdentityPoolId => EnvConfig.cognitoIdentityPoolId;

  /// AWS Region for Cognito services (from environment or fallback)
  static String get cognitoRegion => EnvConfig.cognitoRegion;

  /// OAuth redirect URI for mobile app
  static const String cognitoRedirectUri = 'myapp://callback';

  /// OAuth sign out URI for mobile app
  static const String cognitoSignOutUri = 'myapp://signout';

  // ============================================================================
  // SUPABASE CONFIGURATION
  // ============================================================================
  // These are already configured in your .env file

  /// Supabase project URL (from environment or fallback)
  static String get supabaseUrl => EnvConfig.supabaseUrl;

  /// Supabase anonymous key (from environment or fallback)
  static String get supabaseAnonKey => EnvConfig.supabaseAnonKey;

  // ============================================================================
  // SPEECHIFY API CONFIGURATION
  // ============================================================================

  /// Speechify API key (from environment or fallback)
  /// Get from: https://speechify.com/api
  static String get speechifyApiKey => EnvConfig.speechifyApiKey;

  /// Speechify base URL (from environment or fallback)
  static String get speechifyBaseUrl => EnvConfig.speechifyBaseUrl;

  /// Speechify API URL (alias for base URL)
  static String get speechifyApiUrl => speechifyBaseUrl;

  /// Current auth token (to be set by auth service)
  static String? currentAuthToken;

  // ============================================================================
  // AMPLIFY CONFIGURATION
  // ============================================================================

  /// Generate Amplify configuration JSON
  String get amplifyConfig => '''
{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/2.0",
        "Version": "1.0.0",
        "IdentityManager": {
          "Default": {}
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "$cognitoUserPoolId",
            "AppClientId": "$cognitoClientId",
            "Region": "$cognitoRegion"
          }
        },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "$cognitoIdentityPoolId",
              "Region": "$cognitoRegion"
            }
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "OAuth": {
              "WebDomain": "YOUR_COGNITO_DOMAIN.auth.$cognitoRegion.amazoncognito.com",
              "AppClientId": "$cognitoClientId",
              "SignInRedirectURI": "$cognitoRedirectUri",
              "SignOutRedirectURI": "$cognitoSignOutUri",
              "Scopes": ["email", "openid", "profile"]
            },
            "socialProviders": [],
            "usernameAttributes": ["EMAIL"],
            "signupAttributes": ["EMAIL", "NAME"],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": [
                "REQUIRES_LOWERCASE",
                "REQUIRES_UPPERCASE",
                "REQUIRES_NUMBERS",
                "REQUIRES_SYMBOLS"
              ]
            },
            "mfaConfiguration": "OPTIONAL",
            "mfaTypes": ["SMS"],
            "verificationMechanisms": ["EMAIL"]
          }
        }
      }
    }
  }
}
''';

  // ============================================================================
  // VALIDATION
  // ============================================================================

  /// Check if configuration is complete
  bool get isConfigured {
    return EnvConfig.isCognitoConfigured;
  }

  /// Validate configuration
  void validateConfiguration() {
    // Use EnvConfig's validation
    EnvConfig.printConfigurationStatus();
  }
}

/// Configuration validation helper
void validateAppConfiguration() {
  final config = AppConfig();
  config.validateConfiguration();

  if (!config.isConfigured) {
    // Configuration not complete - check environment variables
  }
}