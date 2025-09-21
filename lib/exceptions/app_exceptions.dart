/// Application Exception Hierarchy
///
/// Purpose: Provides specific exception types for better error handling and debugging
/// Dependencies: None (pure Dart)
///
/// Usage:
///   throw NetworkException('Failed to connect', statusCode: 500);
///   try { ... } on CacheException catch (e) { ... }
///   throw AudioException.invalidFormat('Unsupported audio format');
///
/// Expected behavior:
///   - Clear exception categorization for better error handling
///   - Rich context information for debugging
///   - User-friendly error messages
///   - Logging integration support

/// Base class for all application exceptions
abstract class AppException implements Exception {
  final String message;
  final String? details;
  final int? errorCode;
  final Exception? innerException;

  const AppException(
    this.message, {
    this.details,
    this.errorCode,
    this.innerException,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('$runtimeType: $message');

    if (errorCode != null) {
      buffer.write(' (Error Code: $errorCode)');
    }

    if (details != null) {
      buffer.write(' - $details');
    }

    if (innerException != null) {
      buffer.write(' | Caused by: $innerException');
    }

    return buffer.toString();
  }

  /// Get a user-friendly error message
  String get userMessage => message;

  /// Get technical details for logging
  Map<String, dynamic> get logContext => {
    'type': runtimeType.toString(),
    'message': message,
    if (details != null) 'details': details,
    if (errorCode != null) 'errorCode': errorCode,
    if (innerException != null) 'innerException': innerException.toString(),
  };
}

/// Network-related exceptions
class NetworkException extends AppException {
  final int? statusCode;
  final String? url;

  const NetworkException(
    super.message, {
    this.statusCode,
    this.url,
    super.details,
    super.innerException,
  });

  /// Create network exception from HTTP status code
  factory NetworkException.fromStatusCode(int statusCode, {String? url, String? details}) {
    String message;
    switch (statusCode) {
      case 400:
        message = 'Bad request - invalid data sent to server';
        break;
      case 401:
        message = 'Authentication required - please check your credentials';
        break;
      case 403:
        message = 'Access forbidden - insufficient permissions';
        break;
      case 404:
        message = 'Resource not found';
        break;
      case 429:
        message = 'Too many requests - please try again later';
        break;
      case 500:
        message = 'Internal server error - please try again';
        break;
      case 503:
        message = 'Service temporarily unavailable';
        break;
      default:
        message = 'Network error occurred';
    }

    return NetworkException(
      message,
      statusCode: statusCode,
      url: url,
      details: details,
    );
  }

  /// Connection timeout exception
  factory NetworkException.timeout({String? url}) => NetworkException(
        'Connection timeout - please check your internet connection',
        statusCode: 408,
        url: url,
      );

  /// No internet connection
  factory NetworkException.noConnection() => const NetworkException(
        'No internet connection - please check your network settings',
      );

  @override
  String get userMessage {
    switch (statusCode) {
      case 401:
        return 'Please log in again to continue';
      case 403:
        return 'You don\'t have permission to access this content';
      case 404:
        return 'The requested content was not found';
      case 429:
        return 'Too many requests. Please wait a moment and try again';
      case 500:
      case 503:
        return 'Server is temporarily unavailable. Please try again later';
      default:
        return 'Network error. Please check your connection and try again';
    }
  }

  @override
  Map<String, dynamic> get logContext => {
    ...super.logContext,
    if (statusCode != null) 'statusCode': statusCode,
    if (url != null) 'url': url,
  };
}

/// Cache-related exceptions
class CacheException extends AppException {
  final String? cacheKey;
  final String operation;

  const CacheException(
    super.message, {
    this.cacheKey,
    this.operation = 'unknown',
    super.details,
    super.innerException,
  });

  /// Cache read failure
  factory CacheException.readFailed(String key, {Exception? cause}) =>
      CacheException(
        'Failed to read from cache',
        cacheKey: key,
        operation: 'read',
        innerException: cause,
      );

  /// Cache write failure
  factory CacheException.writeFailed(String key, {Exception? cause}) =>
      CacheException(
        'Failed to write to cache',
        cacheKey: key,
        operation: 'write',
        innerException: cause,
      );

  /// Cache corruption
  factory CacheException.corrupted(String key) => CacheException(
        'Cache data is corrupted',
        cacheKey: key,
        operation: 'validation',
      );

  @override
  String get userMessage => 'Data storage error. Some content may need to be reloaded.';

  @override
  Map<String, dynamic> get logContext => {
    ...super.logContext,
    if (cacheKey != null) 'cacheKey': cacheKey,
    'operation': operation,
  };
}

/// Audio processing exceptions
class AudioException extends AppException {
  final String? audioFormat;
  final String? source;

  const AudioException(
    super.message, {
    this.audioFormat,
    this.source,
    super.details,
    super.errorCode,
    super.innerException,
  });

  /// Invalid audio format
  factory AudioException.invalidFormat(String format) => AudioException(
        'Unsupported audio format',
        audioFormat: format,
        details: 'The audio format "$format" is not supported',
      );

  /// Audio decoding failure
  factory AudioException.decodeFailed({String? source, Exception? cause}) =>
      AudioException(
        'Failed to decode audio data',
        source: source,
        innerException: cause,
      );

  /// Audio streaming error
  factory AudioException.streamingFailed({String? source, Exception? cause}) =>
      AudioException(
        'Audio streaming failed',
        source: source,
        details: 'Unable to stream audio from source',
        innerException: cause,
      );

  /// Audio generation timeout
  factory AudioException.generationTimeout() => const AudioException(
        'Audio generation timed out',
        details: 'The text-to-speech service took too long to respond',
      );

  /// Invalid or missing response data
  factory AudioException.invalidResponse(String message) => AudioException(
        'Invalid API response',
        details: message,
      );

  @override
  String get userMessage {
    if (audioFormat != null) {
      return 'Audio format not supported. Please try a different file.';
    }
    return 'Audio playback error. Please try again.';
  }

  @override
  Map<String, dynamic> get logContext => {
    ...super.logContext,
    if (audioFormat != null) 'audioFormat': audioFormat,
    if (source != null) 'source': source,
  };
}

/// Text processing and timing exceptions
class TimingException extends AppException {
  final String? contentId;
  final String operation;

  const TimingException(
    super.message, {
    this.contentId,
    this.operation = 'unknown',
    super.details,
    super.innerException,
  });

  /// Word timing processing failure
  factory TimingException.processingFailed(String contentId, {Exception? cause}) =>
      TimingException(
        'Failed to process word timing data',
        contentId: contentId,
        operation: 'processing',
        innerException: cause,
      );

  /// Invalid timing data
  factory TimingException.invalidData(String contentId, {String? details}) =>
      TimingException(
        'Invalid timing data format',
        contentId: contentId,
        operation: 'validation',
        details: details,
      );

  /// Timing synchronization error
  factory TimingException.syncError(String contentId) => TimingException(
        'Word timing synchronization failed',
        contentId: contentId,
        operation: 'synchronization',
      );

  @override
  String get userMessage => 'Text synchronization error. Highlighting may not work correctly.';

  @override
  Map<String, dynamic> get logContext => {
    ...super.logContext,
    if (contentId != null) 'contentId': contentId,
    'operation': operation,
  };
}

/// Authentication and authorization exceptions
class AuthException extends AppException {
  final String? userId;
  final String authType;

  const AuthException(
    super.message, {
    this.userId,
    this.authType = 'unknown',
    super.details,
    super.errorCode,
    super.innerException,
  });

  /// Token expired
  factory AuthException.tokenExpired({String? userId}) => AuthException(
        'Authentication token has expired',
        userId: userId,
        authType: 'token',
        errorCode: 401,
      );

  /// Invalid credentials
  factory AuthException.invalidCredentials() => const AuthException(
        'Invalid username or password',
        authType: 'credentials',
        errorCode: 401,
      );

  /// Insufficient permissions
  factory AuthException.insufficientPermissions({String? userId, String? resource}) =>
      AuthException(
        'Insufficient permissions to access resource',
        userId: userId,
        authType: 'authorization',
        details: resource != null ? 'Resource: $resource' : null,
        errorCode: 403,
      );

  @override
  String get userMessage {
    switch (errorCode) {
      case 401:
        return authType == 'token'
            ? 'Your session has expired. Please log in again.'
            : 'Invalid login credentials. Please try again.';
      case 403:
        return 'You don\'t have permission to access this content.';
      default:
        return 'Authentication error. Please try logging in again.';
    }
  }

  @override
  Map<String, dynamic> get logContext => {
    ...super.logContext,
    if (userId != null) 'userId': userId,
    'authType': authType,
  };
}

/// Configuration and setup exceptions
class ConfigurationException extends AppException {
  final String configKey;

  const ConfigurationException(
    super.message, {
    required this.configKey,
    super.details,
    super.innerException,
  });

  /// Missing required configuration
  factory ConfigurationException.missingKey(String key) => ConfigurationException(
        'Required configuration missing',
        configKey: key,
        details: 'Configuration key "$key" is not set',
      );

  /// Invalid configuration value
  factory ConfigurationException.invalidValue(String key, String value) =>
      ConfigurationException(
        'Invalid configuration value',
        configKey: key,
        details: 'Value "$value" is not valid for configuration "$key"',
      );

  @override
  String get userMessage => 'App configuration error. Please contact support.';

  @override
  Map<String, dynamic> get logContext => {
    ...super.logContext,
    'configKey': configKey,
  };
}

/// Validation function to test exception hierarchy
void validateAppExceptions() {
  print('=== AppException Validation ===');

  // Test NetworkException
  final networkEx = NetworkException.fromStatusCode(404, url: 'https://api.example.com');
  assert(networkEx.statusCode == 404);
  assert(networkEx.userMessage.contains('not found'));
  print('✓ NetworkException working');

  // Test CacheException
  final cacheEx = CacheException.readFailed('test-key');
  assert(cacheEx.cacheKey == 'test-key');
  assert(cacheEx.operation == 'read');
  print('✓ CacheException working');

  // Test AudioException
  final audioEx = AudioException.invalidFormat('mp3');
  assert(audioEx.audioFormat == 'mp3');
  assert(audioEx.userMessage.contains('not supported'));
  print('✓ AudioException working');

  // Test TimingException
  final timingEx = TimingException.processingFailed('content-123');
  assert(timingEx.contentId == 'content-123');
  assert(timingEx.operation == 'processing');
  print('✓ TimingException working');

  // Test AuthException
  final authEx = AuthException.tokenExpired(userId: 'user-123');
  assert(authEx.userId == 'user-123');
  assert(authEx.errorCode == 401);
  print('✓ AuthException working');

  // Test ConfigurationException
  final configEx = ConfigurationException.missingKey('api_key');
  assert(configEx.configKey == 'api_key');
  print('✓ ConfigurationException working');

  // Test logContext
  final logContext = networkEx.logContext;
  assert(logContext.containsKey('type'));
  assert(logContext.containsKey('statusCode'));
  print('✓ Log context generation working');

  print('=== All AppException validations passed ===');
}