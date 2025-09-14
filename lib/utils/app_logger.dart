/// Application Logging Utility
///
/// Purpose: Provides structured logging with different levels and consistent formatting
/// Dependencies: None (pure Dart)
///
/// Usage:
///   AppLogger.info('User logged in', {'userId': '123'});
///   AppLogger.error('API call failed', error: e, stackTrace: stack);
///   AppLogger.performance('Binary search completed', {'duration': '5ms'});
///
/// Expected behavior:
///   - Consistent log formatting across the application
///   - Performance tracking capabilities
///   - Production-safe error reporting
///   - Structured data logging

import 'package:flutter/foundation.dart';

/// Log levels for structured logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
  performance,
}

/// Application logger with structured formatting
class AppLogger {
  static const String _tag = 'AudioLearningApp';

  /// Log general information
  static void info(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.info, message, data: data);
  }

  /// Log debug information (only in debug mode)
  static void debug(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      _log(LogLevel.debug, message, data: data);
    }
  }

  /// Log warning messages
  static void warning(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.warning, message, data: data);
  }

  /// Log error messages with optional error details
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    _log(
      LogLevel.error,
      message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log performance metrics
  static void performance(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.performance, message, data: data);
  }

  /// Internal logging method with structured formatting
  static void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();

    // Build structured log entry
    final buffer = StringBuffer();
    buffer.write('[$timestamp] [$_tag] [$levelStr] $message');

    // Add structured data if provided
    if (data != null && data.isNotEmpty) {
      buffer.write(' | Data: ${_formatData(data)}');
    }

    // Add error information if provided
    if (error != null) {
      buffer.write(' | Error: $error');
    }

    // Output log based on level
    final logMessage = buffer.toString();

    switch (level) {
      case LogLevel.debug:
      case LogLevel.info:
      case LogLevel.performance:
        debugPrint(logMessage);
        break;
      case LogLevel.warning:
      case LogLevel.error:
        debugPrint(logMessage);
        if (stackTrace != null) {
          debugPrint('Stack trace: $stackTrace');
        }
        break;
    }
  }

  /// Format structured data for logging
  static String _formatData(Map<String, dynamic> data) {
    return data.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
  }

  /// Log method entry for debugging
  static void methodEntry(String className, String methodName, [Map<String, dynamic>? params]) {
    if (kDebugMode) {
      debug('→ $className.$methodName', params);
    }
  }

  /// Log method exit for debugging
  static void methodExit(String className, String methodName, [Map<String, dynamic>? result]) {
    if (kDebugMode) {
      debug('← $className.$methodName', result);
    }
  }

  /// Log performance timing
  static void timing(String operation, Duration duration, [Map<String, dynamic>? context]) {
    performance(
      '$operation completed',
      {
        'duration': '${duration.inMicroseconds}μs',
        ...?context,
      },
    );
  }

  /// Validation function to verify logging functionality
  static void validate() {
    debugPrint('=== AppLogger Validation ===');

    // Test basic logging levels
    info('Test info message');
    debug('Test debug message');
    warning('Test warning message');

    // Test structured data
    info('Test with data', {'key': 'value', 'count': 42});

    // Test performance logging
    performance('Test performance', {'duration': '100ms'});

    // Test method tracing
    methodEntry('TestClass', 'testMethod', {'param': 'value'});
    methodExit('TestClass', 'testMethod', {'result': 'success'});

    // Test timing
    timing('Test operation', const Duration(microseconds: 1500));

    debugPrint('✅ AppLogger validation complete');
  }
}