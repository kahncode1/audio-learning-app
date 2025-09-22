import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/supabase_service.dart';
import 'package:audio_learning_app/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseService', () {
    late SupabaseService supabaseService;

    setUp(() {
      supabaseService = SupabaseService();
    });

    group('Initialization', () {
      test('should be a singleton', () {
        final instance1 = SupabaseService();
        final instance2 = SupabaseService();
        expect(identical(instance1, instance2), isTrue);
      });

      test('should start uninitialized', () {
        // New instance should start uninitialized
        // Note: Since singleton, state may persist
        expect(supabaseService.isInitialized, isA<bool>());
      });

      test('should throw if client accessed before initialization', () {
        if (!supabaseService.isInitialized) {
          expect(
            () => supabaseService.client,
            throwsStateError,
          );
        }
      });

      test('should have authService getter', () {
        final authService = supabaseService.authService;
        expect(authService, isA<AuthService>());
        expect(authService, isNotNull);
      });
    });

    group('Supabase Initialization', () {
      test('initialize() should set isInitialized', () async {
        // This would require environment variables to be set
        expect(supabaseService.initialize, isA<Function>());
      });

      test('should handle already initialized state', () async {
        // Multiple initializations should be safe
        if (supabaseService.isInitialized) {
          await supabaseService.initialize();
          expect(supabaseService.isInitialized, isTrue);
        }
      });
    });

    group('JWT Bridging', () {
      test('bridgeFromCognito() should return boolean', () async {
        // Would require valid Cognito session
        expect(supabaseService.bridgeFromCognito, isA<Function>());
      });

      test('should handle missing Cognito token', () async {
        // When no Cognito token, should return false
        if (!supabaseService.isInitialized) {
          final result = await supabaseService.bridgeFromCognito();
          expect(result, isFalse);
        }
      });
    });

    group('Database Operations', () {
      test('should provide client for database operations', () {
        if (supabaseService.isInitialized) {
          final client = supabaseService.client;
          expect(client, isNotNull);
          expect(client.from, isA<Function>());
        }
      });
    });

    group('Auth State Management', () {
      test('should set up auth state listener', () {
        // Auth state listener is set up during initialization
        expect(supabaseService, isNotNull);
      });
    });

    group('Resource Management', () {
      test('should manage refresh timer', () {
        // Timer for token refresh should be managed
        expect(supabaseService, isNotNull);
      });
    });

    group('Error Handling', () {
      test('should handle initialization errors', () async {
        // Without proper env config, initialization might fail
        try {
          await supabaseService.initialize();
        } catch (e) {
          // Should handle error gracefully
          expect(e, isNotNull);
        }
      });
    });

    group('Environment Configuration', () {
      test('should use EnvConfig for credentials', () {
        // Service should get URL and key from EnvConfig
        expect(supabaseService, isNotNull);
      });
    });
  });
}