import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/config/env_config.dart';
import 'package:audio_learning_app/config/app_config.dart';

void main() {
  group('Environment Configuration Tests', () {
    setUpAll(() async {
      // Load environment variables once before all tests
      TestWidgetsFlutterBinding.ensureInitialized();
      await EnvConfig.load();
    });

    test('Environment loads successfully', () {
      expect(EnvConfig.environment, isNotEmpty);
      print('✅ Environment: ${EnvConfig.environment}');
    });

    test('Supabase configuration is available', () {
      expect(EnvConfig.supabaseUrl, isNotEmpty);
      expect(EnvConfig.supabaseUrl, contains('supabase'));
      print('✅ Supabase URL: ${EnvConfig.supabaseUrl}');
    });

    test('Speechify configuration check', () {
      final apiKey = EnvConfig.speechifyApiKey;
      expect(apiKey, isNotEmpty);

      if (EnvConfig.isSpeechifyConfigured) {
        print('✅ Speechify is configured with a real API key');
      } else {
        print('⚠️ Speechify API key is still a placeholder');
        print('   Current value: $apiKey');
      }
    });

    test('AppConfig uses environment variables', () {
      final appConfig = AppConfig();

      // Test that AppConfig now uses EnvConfig
      expect(AppConfig.speechifyApiKey, equals(EnvConfig.speechifyApiKey));
      expect(AppConfig.supabaseUrl, equals(EnvConfig.supabaseUrl));
      expect(AppConfig.cognitoUserPoolId, equals(EnvConfig.cognitoUserPoolId));

      print('✅ AppConfig correctly uses environment variables');
    });

    test('Configuration validation', () {
      // Print full configuration status
      EnvConfig.printConfigurationStatus();

      // Check specific configurations
      print('\nDetailed Configuration:');
      print('- Speechify configured: ${EnvConfig.isSpeechifyConfigured}');
      print('- Cognito configured: ${EnvConfig.isCognitoConfigured}');
      print('- Environment type: ${EnvConfig.environment}');
      print('- Is Development: ${EnvConfig.isDevelopment}');
    });

    test('Fallback values work correctly', () {
      // Even if .env is missing, we should have fallback values
      expect(EnvConfig.speechifyBaseUrl, equals('https://api.speechify.com'));
      expect(EnvConfig.cognitoRegion, equals('us-east-1'));
      print('✅ Fallback values are working');
    });
  });
}