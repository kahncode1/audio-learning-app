import 'package:flutter_test/flutter_test.dart';

import 'package:audio_learning_app/exceptions/app_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Exceptions', () {
    group('AppException Base Class', () {
      // Create a concrete implementation for testing
      test('should create base exception with message', () {
        final exception = NetworkException('Test message');
        expect(exception.message, 'Test message');
        expect(exception.details, isNull);
        expect(exception.errorCode, isNull);
        expect(exception.innerException, isNull);
      });

      test('should create exception with all fields', () {
        final innerEx = Exception('Inner error');
        final exception = NetworkException(
          'Test message',
          details: 'Additional details',
          innerException: innerEx,
        );

        expect(exception.message, 'Test message');
        expect(exception.details, 'Additional details');
        expect(exception.innerException, innerEx);
      });

      test('should provide user message', () {
        final exception = NetworkException('Technical message');
        expect(exception.userMessage, isA<String>());
        expect(exception.userMessage, isNotEmpty);
      });

      test('should generate log context', () {
        final exception = NetworkException(
          'Test error',
          details: 'Error details',
        );

        final logContext = exception.logContext;
        expect(logContext, isA<Map<String, dynamic>>());
        expect(logContext['type'], 'NetworkException');
        expect(logContext['message'], 'Test error');
        expect(logContext['details'], 'Error details');
      });

      test('should create proper toString representation', () {
        final innerEx = Exception('Inner error');
        final exception = NetworkException(
          'Main error',
          details: 'Extra info',
          innerException: innerEx,
        );

        final str = exception.toString();
        expect(str, contains('NetworkException'));
        expect(str, contains('Main error'));
        expect(str, contains('Extra info'));
        expect(str, contains('Caused by'));
      });
    });

    group('NetworkException', () {
      test('should create basic network exception', () {
        final exception = NetworkException('Connection failed');
        expect(exception.message, 'Connection failed');
        expect(exception.statusCode, isNull);
        expect(exception.url, isNull);
      });

      test('should create network exception with status code and URL', () {
        final exception = NetworkException(
          'Request failed',
          statusCode: 500,
          url: 'https://api.example.com',
        );

        expect(exception.message, 'Request failed');
        expect(exception.statusCode, 500);
        expect(exception.url, 'https://api.example.com');
      });

      test('should create from status code factory', () {
        final exception = NetworkException.fromStatusCode(
          404,
          url: 'https://test.com',
          details: 'Page missing',
        );

        expect(exception.statusCode, 404);
        expect(exception.url, 'https://test.com');
        expect(exception.details, 'Page missing');
        expect(exception.message, contains('not found'));
      });

      test('should handle common HTTP status codes', () {
        final testCases = [
          (400, 'Bad request'),
          (401, 'Authentication required'),
          (403, 'Access forbidden'),
          (404, 'Resource not found'),
          (429, 'Too many requests'),
          (500, 'Internal server error'),
          (503, 'Service temporarily unavailable'),
        ];

        for (final (statusCode, expectedMessage) in testCases) {
          final exception = NetworkException.fromStatusCode(statusCode);
          expect(exception.statusCode, statusCode);
          expect(exception.message.toLowerCase(), contains(expectedMessage.toLowerCase()));
        }
      });

      test('should create timeout exception', () {
        final exception = NetworkException.timeout(url: 'https://slow.com');
        expect(exception.statusCode, 408);
        expect(exception.url, 'https://slow.com');
        expect(exception.message, contains('timeout'));
      });

      test('should create no connection exception', () {
        final exception = NetworkException.noConnection();
        expect(exception.message, contains('No internet connection'));
      });

      test('should provide user-friendly messages', () {
        final testCases = [
          (401, 'log in again'),
          (403, 'permission'),
          (404, 'not found'),
          (429, 'wait a moment'),
          (500, 'temporarily unavailable'),
          (503, 'try again later'),
        ];

        for (final (statusCode, expectedPhrase) in testCases) {
          final exception = NetworkException.fromStatusCode(statusCode);
          expect(exception.userMessage.toLowerCase(), contains(expectedPhrase));
        }
      });

      test('should include status code and URL in log context', () {
        final exception = NetworkException(
          'Error',
          statusCode: 404,
          url: 'https://test.com',
        );

        final logContext = exception.logContext;
        expect(logContext['statusCode'], 404);
        expect(logContext['url'], 'https://test.com');
      });
    });

    group('CacheException', () {
      test('should create basic cache exception', () {
        final exception = CacheException('Cache error');
        expect(exception.message, 'Cache error');
        expect(exception.cacheKey, isNull);
        expect(exception.operation, 'unknown');
      });

      test('should create cache exception with key and operation', () {
        final exception = CacheException(
          'Operation failed',
          cacheKey: 'user_data',
          operation: 'write',
        );

        expect(exception.message, 'Operation failed');
        expect(exception.cacheKey, 'user_data');
        expect(exception.operation, 'write');
      });

      test('should create read failure exception', () {
        final cause = Exception('Disk error');
        final exception = CacheException.readFailed('test_key', cause: cause);

        expect(exception.message, 'Failed to read from cache');
        expect(exception.cacheKey, 'test_key');
        expect(exception.operation, 'read');
        expect(exception.innerException, cause);
      });

      test('should create write failure exception', () {
        final exception = CacheException.writeFailed('config_key');
        expect(exception.message, 'Failed to write to cache');
        expect(exception.cacheKey, 'config_key');
        expect(exception.operation, 'write');
      });

      test('should create corruption exception', () {
        final exception = CacheException.corrupted('corrupted_key');
        expect(exception.message, 'Cache data is corrupted');
        expect(exception.cacheKey, 'corrupted_key');
        expect(exception.operation, 'validation');
      });

      test('should provide user-friendly message', () {
        final exception = CacheException.readFailed('test');
        expect(exception.userMessage, contains('Data storage error'));
      });

      test('should include cache details in log context', () {
        final exception = CacheException(
          'Error',
          cacheKey: 'test_key',
          operation: 'delete',
        );

        final logContext = exception.logContext;
        expect(logContext['cacheKey'], 'test_key');
        expect(logContext['operation'], 'delete');
      });
    });

    group('AudioException', () {
      test('should create basic audio exception', () {
        final exception = AudioException('Audio error');
        expect(exception.message, 'Audio error');
        expect(exception.audioFormat, isNull);
        expect(exception.source, isNull);
      });

      test('should create audio exception with format and source', () {
        final exception = AudioException(
          'Playback failed',
          audioFormat: 'mp3',
          source: 'https://audio.com/file.mp3',
        );

        expect(exception.message, 'Playback failed');
        expect(exception.audioFormat, 'mp3');
        expect(exception.source, 'https://audio.com/file.mp3');
      });

      test('should create invalid format exception', () {
        final exception = AudioException.invalidFormat('wav');
        expect(exception.message, 'Unsupported audio format');
        expect(exception.audioFormat, 'wav');
        expect(exception.details, contains('wav'));
      });

      test('should create decode failure exception', () {
        final cause = Exception('Decoder error');
        final exception = AudioException.decodeFailed(
          source: 'file.mp3',
          cause: cause,
        );

        expect(exception.message, 'Failed to decode audio data');
        expect(exception.source, 'file.mp3');
        expect(exception.innerException, cause);
      });

      test('should create streaming failure exception', () {
        final exception = AudioException.streamingFailed(
          source: 'stream.url',
        );

        expect(exception.message, 'Audio streaming failed');
        expect(exception.source, 'stream.url');
        expect(exception.details, contains('stream'));
      });

      test('should create generation timeout exception', () {
        final exception = AudioException.generationTimeout();
        expect(exception.message, 'Audio generation timed out');
        expect(exception.details, contains('text-to-speech'));
      });

      test('should create invalid response exception', () {
        final exception = AudioException.invalidResponse('Bad JSON');
        expect(exception.message, 'Invalid API response');
        expect(exception.details, 'Bad JSON');
      });

      test('should provide format-specific user messages', () {
        final formatException = AudioException.invalidFormat('ogg');
        expect(formatException.userMessage, contains('format not supported'));

        final generalException = AudioException('General error');
        expect(generalException.userMessage, contains('playback error'));
      });

      test('should include audio details in log context', () {
        final exception = AudioException(
          'Error',
          audioFormat: 'mp3',
          source: 'test.mp3',
        );

        final logContext = exception.logContext;
        expect(logContext['audioFormat'], 'mp3');
        expect(logContext['source'], 'test.mp3');
      });
    });

    group('TimingException', () {
      test('should create basic timing exception', () {
        final exception = TimingException('Timing error');
        expect(exception.message, 'Timing error');
        expect(exception.contentId, isNull);
        expect(exception.operation, 'unknown');
      });

      test('should create processing failure exception', () {
        final cause = Exception('Parse error');
        final exception = TimingException.processingFailed(
          'content-123',
          cause: cause,
        );

        expect(exception.message, 'Failed to process word timing data');
        expect(exception.contentId, 'content-123');
        expect(exception.operation, 'processing');
        expect(exception.innerException, cause);
      });

      test('should create invalid data exception', () {
        final exception = TimingException.invalidData(
          'content-456',
          details: 'Missing timestamps',
        );

        expect(exception.message, 'Invalid timing data format');
        expect(exception.contentId, 'content-456');
        expect(exception.operation, 'validation');
        expect(exception.details, 'Missing timestamps');
      });

      test('should create sync error exception', () {
        final exception = TimingException.syncError('content-789');
        expect(exception.message, 'Word timing synchronization failed');
        expect(exception.contentId, 'content-789');
        expect(exception.operation, 'synchronization');
      });

      test('should provide user-friendly message', () {
        final exception = TimingException.processingFailed('test');
        expect(exception.userMessage, contains('synchronization error'));
        expect(exception.userMessage, contains('Highlighting'));
      });

      test('should include timing details in log context', () {
        final exception = TimingException(
          'Error',
          contentId: 'content-123',
          operation: 'processing',
        );

        final logContext = exception.logContext;
        expect(logContext['contentId'], 'content-123');
        expect(logContext['operation'], 'processing');
      });
    });

    group('AuthException', () {
      test('should create basic auth exception', () {
        final exception = AuthException('Auth error');
        expect(exception.message, 'Auth error');
        expect(exception.userId, isNull);
        expect(exception.authType, 'unknown');
      });

      test('should create token expired exception', () {
        final exception = AuthException.tokenExpired(userId: 'user-123');
        expect(exception.message, 'Authentication token has expired');
        expect(exception.userId, 'user-123');
        expect(exception.authType, 'token');
        expect(exception.errorCode, 401);
      });

      test('should create invalid credentials exception', () {
        final exception = AuthException.invalidCredentials();
        expect(exception.message, 'Invalid username or password');
        expect(exception.authType, 'credentials');
        expect(exception.errorCode, 401);
      });

      test('should create insufficient permissions exception', () {
        final exception = AuthException.insufficientPermissions(
          userId: 'user-456',
          resource: '/admin/panel',
        );

        expect(exception.message, 'Insufficient permissions to access resource');
        expect(exception.userId, 'user-456');
        expect(exception.authType, 'authorization');
        expect(exception.details, contains('/admin/panel'));
        expect(exception.errorCode, 403);
      });

      test('should provide context-specific user messages', () {
        final tokenException = AuthException.tokenExpired();
        expect(tokenException.userMessage, contains('session has expired'));

        final credentialsException = AuthException.invalidCredentials();
        expect(credentialsException.userMessage, contains('Invalid login'));

        final permissionsException = AuthException.insufficientPermissions();
        expect(permissionsException.userMessage, contains('permission'));
      });

      test('should include auth details in log context', () {
        final exception = AuthException(
          'Error',
          userId: 'user-123',
          authType: 'oauth',
        );

        final logContext = exception.logContext;
        expect(logContext['userId'], 'user-123');
        expect(logContext['authType'], 'oauth');
      });
    });

    group('ConfigurationException', () {
      test('should create basic configuration exception', () {
        final exception = ConfigurationException(
          'Config error',
          configKey: 'api_key',
        );

        expect(exception.message, 'Config error');
        expect(exception.configKey, 'api_key');
      });

      test('should create missing key exception', () {
        final exception = ConfigurationException.missingKey('database_url');
        expect(exception.message, 'Required configuration missing');
        expect(exception.configKey, 'database_url');
        expect(exception.details, contains('database_url'));
      });

      test('should create invalid value exception', () {
        final exception = ConfigurationException.invalidValue('timeout', 'invalid');
        expect(exception.message, 'Invalid configuration value');
        expect(exception.configKey, 'timeout');
        expect(exception.details, contains('timeout'));
        expect(exception.details, contains('invalid'));
      });

      test('should provide user-friendly message', () {
        final exception = ConfigurationException.missingKey('test');
        expect(exception.userMessage, contains('configuration error'));
        expect(exception.userMessage, contains('contact support'));
      });

      test('should include config key in log context', () {
        final exception = ConfigurationException(
          'Error',
          configKey: 'test_key',
        );

        final logContext = exception.logContext;
        expect(logContext['configKey'], 'test_key');
      });
    });

    group('Exception Hierarchy', () {
      test('should implement Exception interface', () {
        final exceptions = [
          NetworkException('test'),
          CacheException('test'),
          AudioException('test'),
          TimingException('test'),
          AuthException('test'),
          ConfigurationException('test', configKey: 'key'),
        ];

        for (final exception in exceptions) {
          expect(exception, isA<Exception>());
          expect(exception, isA<AppException>());
        }
      });

      test('should have consistent toString format', () {
        final exception = NetworkException(
          'Test error',
          statusCode: 404,
          details: 'Not found',
        );

        final str = exception.toString();
        expect(str, startsWith('NetworkException:'));
        expect(str, contains('Test error'));
        expect(str, contains('Error Code: 404'));
        expect(str, contains('Not found'));
      });

      test('should handle null values gracefully', () {
        final exception = NetworkException('Test');
        expect(exception.details, isNull);
        expect(exception.errorCode, isNull);
        expect(exception.innerException, isNull);

        final str = exception.toString();
        expect(str, isA<String>());
        expect(str, isNotEmpty);
      });
    });

    group('Global Validation', () {
      test('should validate all exception types', () {
        expect(() => validateAppExceptions(), returnsNormally);
      });
    });

    group('Log Context Generation', () {
      test('should generate complete log context', () {
        final innerEx = Exception('Inner error');
        final exception = NetworkException(
          'Main error',
          statusCode: 500,
          url: 'https://test.com',
          details: 'Server error',
          innerException: innerEx,
        );

        final logContext = exception.logContext;
        expect(logContext['type'], 'NetworkException');
        expect(logContext['message'], 'Main error');
        expect(logContext['details'], 'Server error');
        expect(logContext['statusCode'], 500);
        expect(logContext['url'], 'https://test.com');
        expect(logContext['innerException'], contains('Inner error'));
      });

      test('should handle missing optional fields in log context', () {
        final exception = NetworkException('Simple error');
        final logContext = exception.logContext;

        expect(logContext['type'], 'NetworkException');
        expect(logContext['message'], 'Simple error');
        expect(logContext.containsKey('details'), isFalse);
        expect(logContext.containsKey('errorCode'), isFalse);
        expect(logContext.containsKey('innerException'), isFalse);
      });
    });

    group('User Message Generation', () {
      test('should provide appropriate user messages for all exception types', () {
        final exceptions = [
          NetworkException.fromStatusCode(401),
          CacheException.readFailed('key'),
          AudioException.invalidFormat('wav'),
          TimingException.syncError('content'),
          AuthException.tokenExpired(),
          ConfigurationException.missingKey('key'),
        ];

        for (final exception in exceptions) {
          final userMessage = exception.userMessage;
          expect(userMessage, isA<String>());
          expect(userMessage, isNotEmpty);
          expect(userMessage.length, greaterThan(10));
        }
      });
    });
  });
}