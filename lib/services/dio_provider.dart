import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
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
  static Dio? _speechifyDio;

  // Enhanced cache configuration with size limits
  static final _cacheOptions = CacheOptions(
    store: MemCacheStore(maxSize: 50 * 1024 * 1024), // 50MB memory cache
    policy: CachePolicy.request,
    hitCacheOnErrorExcept: [401, 403],
    maxStale: const Duration(days: 7),
    priority: CachePriority.normal,
    cipher: null,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );

  // Cache statistics
  static int _cacheHits = 0;
  static int _cacheMisses = 0;

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

    // 2. Cache interceptor
    _dio!.interceptors.add(DioCacheInterceptor(options: _cacheOptions));

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

  /// Get or create a singleton Dio instance for Speechify streaming
  /// This instance has special configuration for audio streaming
  static Dio createSpeechifyClient() {
    final desiredBaseUrl = AppConfig.speechifyApiUrl;

    // Reuse the existing client when the host hasn't changed.
    // If the base URL changes (for example after editing the .env file while
    // the app is still running), rebuild the client so new DNS lookups use the
    // updated host. Without this guard the simulator can stay stuck on the old
    // api.speechify.com endpoint and keep throwing "Failed host lookup".
    if (_speechifyDio != null) {
      if (_speechifyDio!.options.baseUrl == desiredBaseUrl) {
        return _speechifyDio!;
      }

      AppLogger.info('Recreating Speechify Dio client for new base URL', {
        'oldBaseUrl': _speechifyDio!.options.baseUrl,
        'newBaseUrl': desiredBaseUrl,
      });
      _speechifyDio!.close(force: true);
      _speechifyDio = null;
    }

    // Create new instance
    _speechifyDio = Dio(BaseOptions(
      baseUrl: desiredBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(minutes: 5), // Longer for streaming
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer ${AppConfig.speechifyApiKey}',
        'Content-Type': 'application/json',
      },
      // IMPORTANT: Speechify API returns JSON with base64-encoded audio, NOT a stream URL
      // We decode the base64 to bytes and stream those during playback
      // This is NOT downloading files - audio is only in memory during playback
      responseType: ResponseType.json, // API returns JSON with embedded audio data
      validateStatus: (status) => status != null && status < 500,
    ));

    // Add connection pooling (only for native platforms)
    // Commented out due to type compatibility issues
    // TODO: Fix connection pooling for native platforms
    // if (!kIsWeb) {
    //   (_speechifyDio!.httpClientAdapter as dynamic).onHttpClientCreate = (client) {
    //     client.maxConnectionsPerHost = 5; // Connection pooling
    //     return client;
    //   };
    // }

    // Add minimal interceptors for streaming
    _speechifyDio!.interceptors.add(_RetryInterceptor(_speechifyDio!));

    if (kDebugMode) {
      _speechifyDio!.interceptors.add(LogInterceptor(
        request: true,            // Log method + URL
        requestHeader: true,      // Show headers (API key is Bearer; redact happens upstream if needed)
        requestBody: false,       // Avoid logging large audio payloads
        responseHeader: true,     // Show status + headers
        responseBody: false,      // Skip large base64 body
        error: true,
        logPrint: (log) => AppLogger.debug('[SPEECHIFY]', {'message': log}),
      ));
    }

    return _speechifyDio!;
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStatistics() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? (_cacheHits / totalRequests) * 100 : 0.0;

    return {
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': hitRate,
      'totalRequests': totalRequests,
      'cachePolicy': 'LRU',
      'maxCacheSize': '50MB',
      'maxStaleAge': '7 days',
    };
  }

  /// Clear cache statistics
  static void clearCacheStatistics() {
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Clear all cached responses
  static Future<void> clearCache() async {
    try {
      await _cacheOptions.store?.clean();
      AppLogger.info('HTTP cache cleared');
    } catch (e) {
      AppLogger.error('Error clearing cache', error: e);
    }
  }

  /// Monitor cache performance
  static void _monitorCachePerformance(Response response) {
    // Check if response came from cache
    if (response.extra['fromCache'] == true) {
      _cacheHits++;
    } else {
      _cacheMisses++;
    }

    // Log cache performance periodically
    if ((_cacheHits + _cacheMisses) % 100 == 0) {
      final stats = getCacheStatistics();
      AppLogger.info('Cache performance', stats);
    }
  }

  /// Reset the singleton instances (mainly for testing)
  @visibleForTesting
  static void reset() {
    _dio?.close();
    _speechifyDio?.close();
    _dio = null;
    _speechifyDio = null;
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

  // Test 3: Speechify client creation
  final speechifyDio = DioProvider.createSpeechifyClient();
  assert(speechifyDio.options.baseUrl == AppConfig.speechifyApiUrl,
      'Speechify base URL not set');
  assert(speechifyDio.options.responseType == ResponseType.json,
      'JSON response type not set (API returns JSON with base64 audio)');
  AppLogger.debug('✓ Speechify client configuration verified');

  // Test 4: Interceptor order (retry must be last)
  final lastInterceptor = dio.interceptors.last;
  assert(
      lastInterceptor is _RetryInterceptor, 'Retry interceptor must be last');
  AppLogger.debug('✓ Interceptor order verified');

  AppLogger.info('All DioProvider validations passed');
}

