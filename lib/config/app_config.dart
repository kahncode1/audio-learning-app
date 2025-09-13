/// Application Configuration
///
/// Purpose: Centralized configuration for AWS Cognito and Supabase
/// Dependencies: None
///
/// Usage:
///   final config = AppConfig();
///   final userPoolId = config.cognitoUserPoolId;
///
/// IMPORTANT: Update these values with your actual AWS Cognito credentials
/// after creating the resources in AWS Console

class AppConfig {
  // Singleton pattern
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  // ============================================================================
  // AWS COGNITO CONFIGURATION
  // ============================================================================
  // After creating your Cognito User Pool, update these values:

  /// Your Cognito User Pool ID
  /// Format: {region}_{randomString}
  /// Example: 'us-east-1_AbCdEfGhI'
  static const String cognitoUserPoolId = 'YOUR_USER_POOL_ID_HERE';

  /// Your Cognito App Client ID
  /// Found in: User Pool → App Integration → App clients
  /// Example: '1234567890abcdefghijklmnop'
  static const String cognitoClientId = 'YOUR_CLIENT_ID_HERE';

  /// Your Cognito Identity Pool ID
  /// Format: {region}:{uuid}
  /// Example: 'us-east-1:12345678-1234-1234-1234-123456789012'
  static const String cognitoIdentityPoolId = 'YOUR_IDENTITY_POOL_ID_HERE';

  /// AWS Region for Cognito services
  static const String cognitoRegion = 'us-east-1';

  /// OAuth redirect URI for mobile app
  static const String cognitoRedirectUri = 'myapp://callback';

  /// OAuth sign out URI for mobile app
  static const String cognitoSignOutUri = 'myapp://signout';

  // ============================================================================
  // SUPABASE CONFIGURATION
  // ============================================================================
  // These are already configured in your .env file

  /// Supabase project URL
  static const String supabaseUrl = 'https://cmjdciktvfxiyapdseqn.supabase.co';

  /// Supabase anonymous key (public key)
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtamRjaWt0dmZ4aXlhcGRzZXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3ODAwODAsImV4cCI6MjA3MzM1NjA4MH0.qIhF8LgDnm6OrlnhNWNJziNc6OopUu0qCYtgJhXouB8';

  // ============================================================================
  // SPEECHIFY API CONFIGURATION
  // ============================================================================

  /// Speechify API key
  /// Get from: https://speechify.com/api
  static const String speechifyApiKey = 'YOUR_SPEECHIFY_API_KEY_HERE';

  /// Speechify base URL
  static const String speechifyBaseUrl = 'https://api.speechify.com/v1';

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
    return cognitoUserPoolId != 'YOUR_USER_POOL_ID_HERE' &&
           cognitoClientId != 'YOUR_CLIENT_ID_HERE' &&
           cognitoIdentityPoolId != 'YOUR_IDENTITY_POOL_ID_HERE';
  }

  /// Validate configuration
  void validateConfiguration() {
    final missingConfigs = <String>[];

    if (cognitoUserPoolId == 'YOUR_USER_POOL_ID_HERE') {
      missingConfigs.add('Cognito User Pool ID');
    }
    if (cognitoClientId == 'YOUR_CLIENT_ID_HERE') {
      missingConfigs.add('Cognito Client ID');
    }
    if (cognitoIdentityPoolId == 'YOUR_IDENTITY_POOL_ID_HERE') {
      missingConfigs.add('Cognito Identity Pool ID');
    }
    if (speechifyApiKey == 'YOUR_SPEECHIFY_API_KEY_HERE') {
      missingConfigs.add('Speechify API Key');
    }

    if (missingConfigs.isNotEmpty) {
      print('⚠️ Missing configuration:');
      for (final config in missingConfigs) {
        print('  - $config');
      }
      print('\nPlease update lib/config/app_config.dart with your actual credentials.');
    } else {
      print('✅ All configurations are set!');
    }
  }
}

/// Configuration validation helper
void validateAppConfiguration() {
  final config = AppConfig();
  config.validateConfiguration();

  if (!config.isConfigured) {
    print('\n📋 Next Steps:');
    print('1. Create AWS Cognito User Pool and Identity Pool');
    print('2. Update the configuration values in this file');
    print('3. Configure JWT validation in Supabase dashboard');
    print('4. Test the authentication flow');
  }
}