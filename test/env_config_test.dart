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
    });

    test('Supabase configuration is available', () {
      expect(EnvConfig.supabaseUrl, isNotEmpty);
      expect(EnvConfig.supabaseUrl, contains('supabase'));
    });

    test('Speechify configuration check', () {
      final apiKey = EnvConfig.speechifyApiKey;
      expect(apiKey, isNotEmpty);

      if (EnvConfig.isSpeechifyConfigured) {
      } else {}
    });

    test('AppConfig uses environment variables', () {
      AppConfig();

      // Test that AppConfig now uses EnvConfig
      expect(AppConfig.speechifyApiKey, equals(EnvConfig.speechifyApiKey));
      expect(AppConfig.supabaseUrl, equals(EnvConfig.supabaseUrl));
      expect(AppConfig.cognitoUserPoolId, equals(EnvConfig.cognitoUserPoolId));
    });

    test('Configuration validation', () {
      // Print full configuration status
      EnvConfig.printConfigurationStatus();

      // Check specific configurations
    });

    test('Fallback values work correctly', () {
      // Even if .env is missing, we should have fallback values
      expect(EnvConfig.speechifyBaseUrl, equals('https://api.sws.speechify.com'));
      expect(EnvConfig.cognitoRegion, equals('us-east-1'));
    });
  });
}
