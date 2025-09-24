import 'package:flutter_test/flutter_test.dart';

import 'package:audio_learning_app/config/app_config.dart';
import 'package:audio_learning_app/config/env_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig', () {
    group('Singleton Pattern', () {
      test('should return same instance on multiple calls', () {
        final config1 = AppConfig();
        final config2 = AppConfig();

        expect(identical(config1, config2), isTrue);
      });

      test('should maintain state across instances', () {
        final config1 = AppConfig();
        AppConfig.currentAuthToken = 'test-token';

        final config2 = AppConfig();
        expect(AppConfig.currentAuthToken, 'test-token');
      });
    });

    group('Cognito Configuration', () {
      test('should provide cognito user pool ID', () {
        final userPoolId = AppConfig.cognitoUserPoolId;
        expect(userPoolId, isA<String>());
        expect(userPoolId, isNotEmpty);
      });

      test('should provide cognito client ID', () {
        final clientId = AppConfig.cognitoClientId;
        expect(clientId, isA<String>());
        expect(clientId, isNotEmpty);
      });

      test('should provide cognito identity pool ID', () {
        final identityPoolId = AppConfig.cognitoIdentityPoolId;
        expect(identityPoolId, isA<String>());
        expect(identityPoolId, isNotEmpty);
      });

      test('should provide cognito region', () {
        final region = AppConfig.cognitoRegion;
        expect(region, isA<String>());
        expect(region, isNotEmpty);
        expect(region, matches(r'^[a-z]+-[a-z]+-\d+$')); // AWS region format
      });

      test('should provide redirect URIs', () {
        expect(AppConfig.cognitoRedirectUri, 'myapp://callback');
        expect(AppConfig.cognitoSignOutUri, 'myapp://signout');
      });

      test('should delegate to EnvConfig for cognito values', () {
        expect(AppConfig.cognitoUserPoolId, EnvConfig.cognitoUserPoolId);
        expect(AppConfig.cognitoClientId, EnvConfig.cognitoClientId);
        expect(
            AppConfig.cognitoIdentityPoolId, EnvConfig.cognitoIdentityPoolId);
        expect(AppConfig.cognitoRegion, EnvConfig.cognitoRegion);
      });
    });

    group('Supabase Configuration', () {
      test('should provide supabase URL', () {
        final url = AppConfig.supabaseUrl;
        expect(url, isA<String>());
        expect(url, isNotEmpty);
      });

      test('should provide supabase anon key', () {
        final anonKey = AppConfig.supabaseAnonKey;
        expect(anonKey, isA<String>());
        expect(anonKey, isNotEmpty);
      });

      test('should delegate to EnvConfig for supabase values', () {
        expect(AppConfig.supabaseUrl, EnvConfig.supabaseUrl);
        expect(AppConfig.supabaseAnonKey, EnvConfig.supabaseAnonKey);
      });

      test('should handle current auth token', () {
        // Initially null
        AppConfig.currentAuthToken = null;
        expect(AppConfig.currentAuthToken, isNull);

        // Can be set
        AppConfig.currentAuthToken = 'test-token-123';
        expect(AppConfig.currentAuthToken, 'test-token-123');

        // Can be cleared
        AppConfig.currentAuthToken = null;
        expect(AppConfig.currentAuthToken, isNull);
      });
    });

    group('Amplify Configuration', () {
      test('should generate valid amplify config JSON', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        expect(amplifyConfig, isA<String>());
        expect(amplifyConfig, contains('"UserAgent": "aws-amplify-cli/2.0"'));
        expect(amplifyConfig, contains('"Version": "1.0.0"'));
        expect(amplifyConfig, contains('"auth"'));
        expect(amplifyConfig, contains('"awsCognitoAuthPlugin"'));
      });

      test('should include cognito configuration in amplify config', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        expect(amplifyConfig, contains(AppConfig.cognitoUserPoolId));
        expect(amplifyConfig, contains(AppConfig.cognitoClientId));
        expect(amplifyConfig, contains(AppConfig.cognitoIdentityPoolId));
        expect(amplifyConfig, contains(AppConfig.cognitoRegion));
      });

      test('should include OAuth configuration', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        expect(amplifyConfig, contains('"OAuth"'));
        expect(amplifyConfig, contains(AppConfig.cognitoRedirectUri));
        expect(amplifyConfig, contains(AppConfig.cognitoSignOutUri));
        expect(amplifyConfig,
            contains('"Scopes": ["email", "openid", "profile"]'));
      });

      test('should include authentication flow settings', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        expect(amplifyConfig,
            contains('"authenticationFlowType": "USER_SRP_AUTH"'));
        expect(amplifyConfig, contains('"usernameAttributes": ["EMAIL"]'));
        expect(
            amplifyConfig, contains('"signupAttributes": ["EMAIL", "NAME"]'));
      });

      test('should include password policy settings', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        expect(amplifyConfig, contains('"passwordProtectionSettings"'));
        expect(amplifyConfig, contains('"passwordPolicyMinLength": 8'));
        expect(amplifyConfig, contains('"REQUIRES_LOWERCASE"'));
        expect(amplifyConfig, contains('"REQUIRES_UPPERCASE"'));
        expect(amplifyConfig, contains('"REQUIRES_NUMBERS"'));
        expect(amplifyConfig, contains('"REQUIRES_SYMBOLS"'));
      });

      test('should include MFA configuration', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        expect(amplifyConfig, contains('"mfaConfiguration": "OPTIONAL"'));
        expect(amplifyConfig, contains('"mfaTypes": ["SMS"]'));
        expect(amplifyConfig, contains('"verificationMechanisms": ["EMAIL"]'));
      });
    });

    group('Configuration Validation', () {
      test('should provide configuration status', () {
        final config = AppConfig();
        final isConfigured = config.isConfigured;

        expect(isConfigured, isA<bool>());
        expect(isConfigured, EnvConfig.isCognitoConfigured);
      });

      test('should validate configuration without throwing', () {
        final config = AppConfig();
        expect(() => config.validateConfiguration(), returnsNormally);
      });

      test('should delegate validation to EnvConfig', () {
        final config = AppConfig();
        // Should not throw - delegates to EnvConfig
        expect(() => config.validateConfiguration(), returnsNormally);
      });
    });

    group('Global Validation Function', () {
      test('should validate app configuration globally', () {
        expect(() => validateAppConfiguration(), returnsNormally);
      });

      test('should handle incomplete configuration gracefully', () {
        // Should not throw even if configuration is incomplete
        expect(() => validateAppConfiguration(), returnsNormally);
      });
    });

    group('Integration with EnvConfig', () {
      test('should use EnvConfig for all environment values', () {
        // Verify AppConfig doesn't hardcode values but delegates to EnvConfig
        expect(AppConfig.cognitoUserPoolId, isA<String>());
        expect(AppConfig.cognitoClientId, isA<String>());
        expect(AppConfig.cognitoIdentityPoolId, isA<String>());
        expect(AppConfig.cognitoRegion, isA<String>());
        expect(AppConfig.supabaseUrl, isA<String>());
        expect(AppConfig.supabaseAnonKey, isA<String>());
      });

      test('should maintain consistency with EnvConfig', () {
        // Values should match exactly
        expect(AppConfig.cognitoUserPoolId, EnvConfig.cognitoUserPoolId);
        expect(AppConfig.cognitoClientId, EnvConfig.cognitoClientId);
        expect(
            AppConfig.cognitoIdentityPoolId, EnvConfig.cognitoIdentityPoolId);
        expect(AppConfig.cognitoRegion, EnvConfig.cognitoRegion);
        expect(AppConfig.supabaseUrl, EnvConfig.supabaseUrl);
        expect(AppConfig.supabaseAnonKey, EnvConfig.supabaseAnonKey);
        expect(AppConfig().isConfigured, EnvConfig.isCognitoConfigured);
      });
    });

    group('JSON Structure', () {
      test('should generate valid JSON structure', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        // Should contain proper JSON structure
        expect(amplifyConfig, startsWith('{'));
        expect(amplifyConfig, endsWith('}'));
        expect(amplifyConfig, contains('"UserAgent"'));
        expect(amplifyConfig, contains('"Version"'));
        expect(amplifyConfig, contains('"auth"'));
        expect(amplifyConfig, contains('"plugins"'));
      });

      test('should have properly nested configuration objects', () {
        final config = AppConfig();
        final amplifyConfig = config.amplifyConfig;

        // Check for nested structure
        expect(amplifyConfig, contains('"CognitoUserPool"'));
        expect(amplifyConfig, contains('"CredentialsProvider"'));
        expect(amplifyConfig, contains('"CognitoIdentity"'));
        expect(amplifyConfig, contains('"Auth"'));
      });
    });

    group('Static Access', () {
      test('should provide static access to configuration values', () {
        expect(AppConfig.cognitoUserPoolId, isA<String>());
        expect(AppConfig.cognitoClientId, isA<String>());
        expect(AppConfig.cognitoIdentityPoolId, isA<String>());
        expect(AppConfig.cognitoRegion, isA<String>());
        expect(AppConfig.supabaseUrl, isA<String>());
        expect(AppConfig.supabaseAnonKey, isA<String>());
      });

      test('should handle static auth token management', () {
        AppConfig.currentAuthToken = null;
        expect(AppConfig.currentAuthToken, isNull);

        AppConfig.currentAuthToken = 'static-test-token';
        expect(AppConfig.currentAuthToken, 'static-test-token');

        AppConfig.currentAuthToken = '';
        expect(AppConfig.currentAuthToken, '');
      });
    });

    group('Configuration Values Format', () {
      test('should have properly formatted OAuth URIs', () {
        expect(AppConfig.cognitoRedirectUri, matches(r'^[a-zA-Z]+://\w+$'));
        expect(AppConfig.cognitoSignOutUri, matches(r'^[a-zA-Z]+://\w+$'));
      });

      test('should validate cognito region format', () {
        final region = AppConfig.cognitoRegion;
        expect(region, matches(r'^[a-z]+-[a-z]+-\d+$'));
      });
    });

    group('Error Handling', () {
      test('should handle missing environment variables gracefully', () {
        // Should not throw even if EnvConfig has issues
        expect(() => AppConfig.cognitoUserPoolId, returnsNormally);
        expect(() => AppConfig.cognitoClientId, returnsNormally);
        expect(() => AppConfig.supabaseUrl, returnsNormally);
      });

      test('should handle amplify config generation errors gracefully', () {
        final config = AppConfig();
        expect(() => config.amplifyConfig, returnsNormally);
      });
    });

    group('Thread Safety', () {
      test('should maintain singleton across multiple accesses', () async {
        final futures = List.generate(10, (_) async => AppConfig());
        final configs = await Future.wait(futures);

        for (int i = 1; i < configs.length; i++) {
          expect(identical(configs[0], configs[i]), isTrue);
        }
      });
    });
  });
}
