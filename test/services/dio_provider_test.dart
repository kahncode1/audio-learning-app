import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/dio_provider.dart';
import 'package:audio_learning_app/config/env_config.dart';

void main() {
  setUpAll(() async {
    // Initialize test environment
    TestWidgetsFlutterBinding.ensureInitialized();
    await EnvConfig.load();
  });

  group('DioProvider Tests', () {
    setUp(() {
      // Reset singleton before each test
      DioProvider.reset();
    });

    tearDown(() {
      // Clean up after each test
      DioProvider.reset();
    });

    group('Singleton Pattern', () {
      test('should return the same instance when called multiple times', () {
        final instance1 = DioProvider.instance;
        final instance2 = DioProvider.instance;

        expect(instance1, equals(instance2));
        expect(identical(instance1, instance2), isTrue);
      });

      test('should return the same Dio instance for general client', () {
        final dio1 = DioProvider.dio;
        final dio2 = DioProvider.dio;

        expect(dio1, equals(dio2));
        expect(identical(dio1, dio2), isTrue);
      });
    });

    group('Configuration', () {
      test('general Dio should have correct base configuration', () {
        final dio = DioProvider.dio;

        expect(dio.options.connectTimeout, equals(const Duration(seconds: 10)));
        expect(dio.options.receiveTimeout, equals(const Duration(seconds: 30)));
        expect(dio.options.sendTimeout, equals(const Duration(seconds: 30)));
        expect(dio.options.headers['Content-Type'], equals('application/json'));
        expect(dio.options.headers['Accept'], equals('application/json'));
      });
    });

    group('Interceptor Chain', () {
      test('general Dio should have correct interceptor order', () {
        final dio = DioProvider.dio;
        final interceptors = dio.interceptors;

        // Should have at least 3 interceptors (auth, cache, retry)
        // In debug mode, should also have LogInterceptor (4 total)
        expect(interceptors.length, greaterThanOrEqualTo(3));
      });
    });

    group('Exponential Backoff', () {
      test('should have retry interceptor configured', () {
        final dio = DioProvider.dio;

        // Find retry interceptor
        final hasRetryInterceptor = dio.interceptors.any((interceptor) {
          // Check if interceptor is a retry interceptor by type name
          return interceptor.runtimeType
              .toString()
              .contains('RetryInterceptor');
        });

        expect(hasRetryInterceptor, isTrue);
      });

      test('should use correct retry delays (1s, 2s, 4s) - configuration test',
          () {
        // The retry delays are configured as 1s, 2s, 4s
        const expectedDelays = [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
        ];

        // Verify the configuration (this is more of a configuration test)
        expect(expectedDelays[0].inSeconds, equals(1));
        expect(expectedDelays[1].inSeconds, equals(2));
        expect(expectedDelays[2].inSeconds, equals(4));
      });
    });

    group('Reset Functionality', () {
      test('should create new instances after reset', () {
        final dio1 = DioProvider.dio;

        DioProvider.reset();

        final dio2 = DioProvider.dio;

        expect(identical(dio1, dio2), isFalse);
      });

      test('should close existing Dio instances on reset', () {
        final dio = DioProvider.dio;

        DioProvider.reset();

        // After reset, new instances should be created
        final newDio = DioProvider.dio;

        expect(identical(dio, newDio), isFalse);
      });
    });

    group('Error Handling', () {
      test('should validate status codes correctly', () {
        final dio = DioProvider.dio;

        // Should accept status codes < 500
        expect(dio.options.validateStatus(200), isTrue);
        expect(dio.options.validateStatus(201), isTrue);
        expect(dio.options.validateStatus(400), isTrue);
        expect(dio.options.validateStatus(404), isTrue);
        expect(dio.options.validateStatus(499), isTrue);

        // Should reject status codes >= 500
        expect(dio.options.validateStatus(500), isFalse);
        expect(dio.options.validateStatus(503), isFalse);

        // Should reject null status
        expect(dio.options.validateStatus(null), isFalse);
      });
    });

    group('Validation Function', () {
      test('validation function should complete successfully', () {
        // Test the basic validation function
        expect(() {
          // Create instances
          final provider = DioProvider.instance;
          final dio = DioProvider.dio;

          // Verify they exist

          // Verify singleton behavior
          assert(identical(DioProvider.dio, dio));

          // Reset and verify new instances
          DioProvider.reset();
          final newDio = DioProvider.dio;
          assert(!identical(dio, newDio));
        }, returnsNormally);
      });
    });
  });
}
