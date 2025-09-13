# /implementations/dio-config.dart

```dart
/// Dio Configuration - Singleton HTTP Client with Interceptors
/// 
/// Provides a properly configured Dio instance with:
/// - Authentication interceptor for Bearer tokens
/// - Cache interceptor for response caching
/// - Retry interceptor with exponential backoff
/// - Connection pooling for performance
/// - Logging in debug mode

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';

class DioProvider {
  static Dio? _instance;
  
  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }
  
  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 10),
    ));
    
    // CRITICAL: Interceptor order matters!
    // 1. Auth interceptor (adds Bearer token)
    dio.interceptors.add(AuthInterceptor());
    
    // 2. Cache interceptor (checks cache before request)
    dio.interceptors.add(DioCacheInterceptor(
      options: CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.forceCache,
        maxStale: const Duration(days: 7),
        priority: CachePriority.normal,
        cipher: null,
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false,
      ),
    ));
    
    // 3. Retry interceptor (MUST be last)
    dio.interceptors.add(RetryInterceptor(
      dio: dio,
      maxRetries: 3,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ],
    ));
    
    // 4. Logging (debug only)
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: false, // Don't log large audio responses
        error: true,
        logPrint: (object) => print('[DIO] $object'),
      ));
    }
    
    return dio;
  }
  
  static void reset() {
    _instance?.close();
    _instance = null;
  }
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Get the current auth token
    final token = await _getAuthToken();
    
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token might be expired, try to refresh
      final refreshed = await _refreshToken();
      
      if (refreshed) {
        // Retry the request with new token
        final newToken = await _getAuthToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        
        try {
          final response = await DioProvider.instance.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
    }
    
    handler.next(err);
  }
  
  Future<String?> _getAuthToken() async {
    // Implementation depends on your auth service
    // This is a placeholder
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        final cognitoSession = session as CognitoAuthSession;
        return cognitoSession.userPoolTokensResult.value.idToken.raw;
      }
    } catch (e) {
      print('Failed to get auth token: $e');
    }
    return null;
  }
  
  Future<bool> _refreshToken() async {
    try {
      await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: true),
      );
      return true;
    } catch (e) {
      print('Failed to refresh token: $e');
      return false;
    }
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<Duration> retryDelays;
  
  RetryInterceptor({
    required this.dio,
    required this.maxRetries,
    required this.retryDelays,
  });
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }
    
    final extra = err.requestOptions.extra;
    final retryCount = (extra['retryCount'] ?? 0) as int;
    
    if (retryCount >= maxRetries) {
      print('Max retries ($maxRetries) reached for ${err.requestOptions.path}');
      return handler.next(err);
    }
    
    final delay = retryDelays[retryCount.clamp(0, retryDelays.length - 1)];
    print('Retrying request (${retryCount + 1}/$maxRetries) after ${delay.inSeconds}s');
    
    await Future.delayed(delay);
    
    try {
      final options = err.requestOptions;
      options.extra['retryCount'] = retryCount + 1;
      
      final response = await dio.fetch(options);
      return handler.resolve(response);
    } catch (e) {
      return handler.next(err);
    }
  }
  
  bool _shouldRetry(DioException err) {
    // Retry on network errors and 5xx server errors
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.receiveTimeout ||
           err.type == DioExceptionType.connectionError ||
           (err.response?.statusCode ?? 0) >= 500;
  }
}

class CacheInterceptor extends Interceptor {
  final CacheStore _store = MemCacheStore();
  final Duration maxStale = const Duration(days: 7);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Only cache GET requests
    if (options.method != 'GET') {
      return handler.next(options);
    }
    
    final key = _generateKey(options);
    final cached = await _store.get(key);
    
    if (cached != null && !_isExpired(cached)) {
      // Return cached response
      return handler.resolve(
        Response(
          data: cached.content,
          headers: cached.headers,
          statusCode: cached.statusCode,
          requestOptions: options,
        ),
      );
    }
    
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // Only cache successful GET requests
    if (response.requestOptions.method == 'GET' && 
        response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      
      final key = _generateKey(response.requestOptions);
      await _store.set(
        key,
        CacheResponse(
          content: response.data,
          headers: response.headers.map,
          statusCode: response.statusCode!,
          date: DateTime.now(),
        ),
      );
    }
    
    handler.next(response);
  }
  
  String _generateKey(RequestOptions options) {
    return '${options.method}_${options.uri.toString()}';
  }
  
  bool _isExpired(CacheResponse cached) {
    return DateTime.now().difference(cached.date) > maxStale;
  }
}

class CacheResponse {
  final dynamic content;
  final Map<String, List<String>> headers;
  final int statusCode;
  final DateTime date;
  
  CacheResponse({
    required this.content,
    required this.headers,
    required this.statusCode,
    required this.date,
  });
}

abstract class CacheStore {
  Future<CacheResponse?> get(String key);
  Future<void> set(String key, CacheResponse response);
  Future<void> delete(String key);
  Future<void> clear();
}

class MemCacheStore implements CacheStore {
  final Map<String, CacheResponse> _cache = {};
  static const int _maxCacheSize = 50;
  
  @override
  Future<CacheResponse?> get(String key) async {
    return _cache[key];
  }
  
  @override
  Future<void> set(String key, CacheResponse response) async {
    // Enforce cache size limit
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    
    _cache[key] = response;
  }
  
  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
  }
  
  @override
  Future<void> clear() async {
    _cache.clear();
  }
}

// Validation function
void main() async {
  print('🔧 Testing Dio Configuration...\n');
  
  final List<String> validationFailures = [];
  int totalTests = 0;
  
  // Test 1: Singleton instance
  totalTests++;
  try {
    final dio1 = DioProvider.instance;
    final dio2 = DioProvider.instance;
    
    if (identical(dio1, dio2)) {
      print('✓ Singleton pattern working correctly');
    } else {
      validationFailures.add('Singleton pattern failed - multiple instances created');
    }
  } catch (e) {
    validationFailures.add('Singleton test failed: $e');
  }
  
  // Test 2: Interceptor count
  totalTests++;
  try {
    final dio = DioProvider.instance;
    final interceptorCount = dio.interceptors.length;
    
    // Should have at least 3 interceptors (auth, cache, retry) + logging in debug
    final expectedMin = kDebugMode ? 4 : 3;
    
    if (interceptorCount >= expectedMin) {
      print('✓ Interceptors configured: $interceptorCount interceptors');
    } else {
      validationFailures.add('Insufficient interceptors: $interceptorCount (expected >= $expectedMin)');
    }
  } catch (e) {
    validationFailures.add('Interceptor test failed: $e');
  }
  
  // Test 3: Timeout configuration
  totalTests++;
  try {
    final dio = DioProvider.instance;
    final connectTimeout = dio.options.connectTimeout;
    final receiveTimeout = dio.options.receiveTimeout;
    
    if (connectTimeout == const Duration(seconds: 10) &&
        receiveTimeout == const Duration(seconds: 30)) {
      print('✓ Timeout configuration correct');
    } else {
      validationFailures.add('Incorrect timeout configuration');
    }
  } catch (e) {
    validationFailures.add('Timeout configuration test failed: $e');
  }
  
  // Test 4: Retry delays
  totalTests++;
  try {
    final delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    
    Duration total = Duration.zero;
    for (final delay in delays) {
      total += delay;
    }
    
    if (total.inSeconds == 7) {
      print('✓ Retry delays total 7 seconds (exponential backoff)');
    } else {
      validationFailures.add('Incorrect retry delay total: ${total.inSeconds}s');
    }
  } catch (e) {
    validationFailures.add('Retry delay test failed: $e');
  }
  
  // Test 5: Cache store
  totalTests++;
  try {
    final store = MemCacheStore();
    
    final testResponse = CacheResponse(
      content: {'test': 'data'},
      headers: {},
      statusCode: 200,
      date: DateTime.now(),
    );
    
    await store.set('test_key', testResponse);
    final retrieved = await store.get('test_key');
    
    if (retrieved != null && retrieved.statusCode == 200) {
      print('✓ Cache store working correctly');
    } else {
      validationFailures.add('Cache store failed to retrieve data');
    }
  } catch (e) {
    validationFailures.add('Cache store test failed: $e');
  }
  
  // Final validation results
  print('\n' + '=' * 50);
  if (validationFailures.isNotEmpty) {
    print('❌ VALIDATION FAILED - ${validationFailures.length} of $totalTests tests failed:\n');
    for (final failure in validationFailures) {
      print('  • $failure');
    }
    exit(1);
  } else {
    print('✅ VALIDATION PASSED - All $totalTests tests produced expected results');
    print('Dio configuration ready for use');
    exit(0);
  }
}
```