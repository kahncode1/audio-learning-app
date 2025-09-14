import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

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

  // Cache configuration
  static final _cacheOptions = CacheOptions(
    store: MemCacheStore(),
    policy: CachePolicy.request,
    hitCacheOnErrorExcept: [401, 403],
    maxStale: const Duration(days: 7),
    priority: CachePriority.normal,
    cipher: null,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );

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
        logPrint: (log) => debugPrint('[DIO] $log'),
      ));
    }

    // 4. Retry interceptor (MUST be last)
    _dio!.interceptors.add(_RetryInterceptor(_dio!));
  }

  /// Create a separate Dio instance for Speechify streaming
  /// This instance has special configuration for audio streaming
  static Dio createSpeechifyClient() {
    final speechifyDio = Dio(BaseOptions(
      baseUrl: AppConfig.speechifyApiUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(minutes: 5), // Longer for streaming
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer ${AppConfig.speechifyApiKey}',
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.stream, // For audio streaming
      validateStatus: (status) => status != null && status < 500,
    ));

    // Add connection pooling
    (speechifyDio.httpClientAdapter as dynamic).onHttpClientCreate = (client) {
      client.maxConnectionsPerHost = 5; // Connection pooling
      return client;
    };

    // Add minimal interceptors for streaming
    speechifyDio.interceptors.add(_RetryInterceptor(speechifyDio));

    if (kDebugMode) {
      speechifyDio.interceptors.add(LogInterceptor(
        requestBody: false, // Don't log audio data
        responseBody: false,
        error: true,
        logPrint: (log) => debugPrint('[SPEECHIFY] $log'),
      ));
    }

    return speechifyDio;
  }

  /// Reset the singleton instance (mainly for testing)
  @visibleForTesting
  static void reset() {
    _dio?.close();
    _dio = null;
    _instance = null;
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
      debugPrint('Authentication failed: ${err.message}');
    }
    handler.next(err);
  }
}

/// Retry interceptor with exponential backoff
class _RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<int> retryDelays;

  _RetryInterceptor(this.dio, {
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

      debugPrint('Retrying request (attempt ${retryCount + 1}/$maxRetries) after ${delay}ms...');

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
  debugPrint('=== DioProvider Validation ===');

  // Test 1: Singleton pattern
  final instance1 = DioProvider.instance;
  final instance2 = DioProvider.instance;
  assert(identical(instance1, instance2), 'DioProvider must be a singleton');
  debugPrint('✓ Singleton pattern verified');

  // Test 2: Dio instance configuration
  final dio = DioProvider.dio;
  assert(dio.options.connectTimeout == const Duration(seconds: 10), 'Connect timeout not set correctly');
  assert(dio.interceptors.length >= 3, 'Missing interceptors');
  debugPrint('✓ Dio configuration verified');

  // Test 3: Speechify client creation
  final speechifyDio = DioProvider.createSpeechifyClient();
  assert(speechifyDio.options.baseUrl == AppConfig.speechifyApiUrl, 'Speechify base URL not set');
  assert(speechifyDio.options.responseType == ResponseType.stream, 'Stream response type not set');
  debugPrint('✓ Speechify client configuration verified');

  // Test 4: Interceptor order (retry must be last)
  final lastInterceptor = dio.interceptors.last;
  assert(lastInterceptor is _RetryInterceptor, 'Retry interceptor must be last');
  debugPrint('✓ Interceptor order verified');

  debugPrint('=== All DioProvider validations passed ===');
}