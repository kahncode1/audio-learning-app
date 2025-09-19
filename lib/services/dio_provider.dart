import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// DioProvider - Singleton HTTP client for all network requests
///
/// CRITICAL: This must be a singleton to prevent connection issues.
/// Never create multiple Dio instances - always use DioProvider.instance
///
/// Features:
/// - Connection pooling for improved performance
/// - Request/response caching to reduce API calls
/// - Exponential backoff retry logic (1s, 2s, 4s)
/// - Authentication header injection
/// - Debug logging in development mode
class DioProvider {
  static DioProvider? _instance;
  static Dio? _dio;


  // Private constructor
  DioProvider._();

  /// Get the singleton instance of DioProvider
  static DioProvider get instance {
    _instance ??= DioProvider._();
    return _instance!;
  }

  /// Get the configured Dio instance
  static Dio get dio {
    if (_dio == null) {
      _dio = Dio(_baseOptions);
      _setupInterceptors();
    }
    return _dio!;
  }

  /// Base options for all requests
  static BaseOptions get _baseOptions => BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      );

  /// Configure all interceptors
  static void _setupInterceptors() {
    if (_dio == null) return;

    // Clear any existing interceptors
    _dio!.interceptors.clear();

    // 1. Authentication interceptor (first)
    _dio!.interceptors.add(_AuthInterceptor());

    // 2. Cache interceptor removed (was using dio_cache_interceptor)

    // 3. Logging interceptor (debug only)
    if (kDebugMode) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: true,
        responseHeader: false,
        request: true,
        logPrint: (log) => AppLogger.debug('[DIO]', {'message': log}),
      ));
    }

    // 4. Retry interceptor (MUST be last)
    _dio!.interceptors.add(_RetryInterceptor(_dio!));
  }


  /// Get cache statistics (placeholder for future implementation)
  static Map<String, dynamic> getCacheStatistics() {
    return {
      'cacheHits': 0,
      'cacheMisses': 0,
      'hitRate': 0.0,
      'totalRequests': 0,
      'cacheEnabled': false,
    };
  }

  /// Clear cache statistics (placeholder for future implementation)
  static void clearCacheStatistics() {
    // Cache statistics removed - this is a no-op for now
  }

  /// Clear all cached responses (placeholder for future implementation)
  static Future<void> clearCache() async {
    // Cache removed - this is a no-op for now
    AppLogger.info('Cache clearing requested (cache not currently implemented)');
  }


  /// Reset the singleton instances (mainly for testing)
  @visibleForTesting
  static void reset() {
    _dio?.close();
    _dio = null;
    _instance = null;
    clearCacheStatistics();
  }
}

/// Authentication interceptor to add auth headers
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add auth token if available and not already present
    if (!options.headers.containsKey('Authorization')) {
      final token = AppConfig.currentAuthToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid
      // TODO: Implement token refresh logic here
      AppLogger.warning('Authentication failed', {
        'statusCode': err.response?.statusCode,
        'message': err.message,
      });
    }
    handler.next(err);
  }
}

/// Retry interceptor with exponential backoff
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<int> retryDelays;

  _RetryInterceptor(
    this.dio, {
    this.maxRetries = 3,
    this.retryDelays = const [1000, 2000, 4000], // Exponential backoff in ms
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only retry on network errors or 5xx errors
    final shouldRetry = _shouldRetry(err);
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

    if (shouldRetry && retryCount < maxRetries) {
      // Calculate delay
      final delay = retryCount < retryDelays.length
          ? retryDelays[retryCount]
          : retryDelays.last;

      AppLogger.info('Retrying request', {
        'attempt': retryCount + 1,
        'maxRetries': maxRetries,
        'delay': '${delay}ms',
      });

      // Wait before retrying
      await Future.delayed(Duration(milliseconds: delay));

      try {
        // Clone the request with updated retry count
        final options = err.requestOptions;
        options.extra['retryCount'] = retryCount + 1;

        final response = await dio.fetch(options);
        handler.resolve(response);
      } catch (e) {
        // If retry also fails, pass the error forward
        if (e is DioException) {
          handler.next(e);
        } else {
          handler.next(err);
        }
      }
    } else {
      // No retry needed or max retries reached
      handler.next(err);
    }
  }

  bool _shouldRetry(DioException err) {
    // Retry on network errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on 5xx server errors
    final statusCode = err.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) {
      return true;
    }

    // Don't retry on client errors (4xx) or other issues
    return false;
  }
}

/// Validation function for DioProvider
void validateDioProvider() {
  AppLogger.info('Starting DioProvider validation');

  // Test 1: Singleton pattern
  final instance1 = DioProvider.instance;
  final instance2 = DioProvider.instance;
  assert(identical(instance1, instance2), 'DioProvider must be a singleton');
  AppLogger.debug('✓ Singleton pattern verified');

  // Test 2: Dio instance configuration
  final dio = DioProvider.dio;
  assert(dio.options.connectTimeout == const Duration(seconds: 10),
      'Connect timeout not set correctly');
  assert(dio.interceptors.length >= 3, 'Missing interceptors');
  AppLogger.debug('✓ Dio configuration verified');

  // Test 3: Interceptor order (retry must be last)
  final lastInterceptor = dio.interceptors.last;
  assert(
      lastInterceptor is _RetryInterceptor, 'Retry interceptor must be last');
  AppLogger.debug('✓ Interceptor order verified');

  AppLogger.info('All DioProvider validations passed');
}

