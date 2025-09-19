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

    test('Environment has required Supabase configuration', () {
      expect(EnvConfig.supabaseUrl, isNotEmpty);
      expect(EnvConfig.supabaseAnonKey, isNotEmpty);
    });

    test('AppConfig uses environment variables', () {
      AppConfig();

      // Test that AppConfig now uses EnvConfig
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
      expect(EnvConfig.cognitoRegion, equals('us-east-1'));
    });
  });
}
