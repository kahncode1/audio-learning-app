/// Error Tracking Service
///
/// Purpose: Centralized error tracking and crash reporting for the application
/// Features:
/// - Integration with Sentry for crash reporting
/// - Comprehensive error logging with context
/// - User feedback collection for errors
/// - Performance transaction tracking
/// - Breadcrumb tracking for debugging
///
/// Dependencies:
/// - sentry_flutter: Crash reporting and performance monitoring
/// - AppLogger: Local logging infrastructure
///
/// Usage:
/// ```dart
/// ErrorTrackingService.initialize(dsn: 'your-sentry-dsn');
/// ErrorTrackingService.reportError(error, stackTrace, context: {'user_id': '123'});
/// ```

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../utils/app_logger.dart';

class ErrorTrackingService {
  static bool _initialized = false;
  static const String _environment = kDebugMode ? 'development' : 'production';

  /// Initialize error tracking with Sentry
  static Future<void> initialize({
    required String dsn,
    double tracesSampleRate = 0.3,
  }) async {
    if (_initialized) {
      AppLogger.warning('ErrorTrackingService already initialized');
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = _environment;
        options.tracesSampleRate = tracesSampleRate;
        options.debug = kDebugMode;
        options.sendDefaultPii = false; // Don't send personally identifiable information
        options.attachScreenshot = false; // Don't attach screenshots by default
        options.attachViewHierarchy = true; // Attach view hierarchy for debugging

        // Set release name
        options.release = 'audio-learning-app@1.0.0';

        // Configure which errors to capture
        options.beforeSend = (event, hint) {
          // Filter out certain errors in development
          if (kDebugMode) {
            final error = event.throwable;
            if (error is FlutterError &&
                error.message.contains('setState() or markNeedsBuild()')) {
              return null; // Don't send setState errors in development
            }
          }

          // Log locally as well
          AppLogger.error(
            'Sending to Sentry',
            error: event.throwable,
          );

          return event;
        };

        // Set up performance monitoring
        options.enableAutoPerformanceTracing = true;
      },
    );

    _initialized = true;
    AppLogger.info('ErrorTrackingService initialized', {
      'environment': _environment,
      'tracesSampleRate': tracesSampleRate,
    });
  }

  /// Report an error to Sentry
  static Future<void> reportError(
    dynamic error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
    SentryLevel level = SentryLevel.error,
    String? message,
  }) async {
    if (!_initialized) {
      AppLogger.error('ErrorTrackingService not initialized', error: error, stackTrace: stackTrace);
      return;
    }

    // Add context if provided
    if (context != null) {
      await Sentry.configureScope((scope) {
        context.forEach((key, value) {
          scope.setExtra(key, value);
        });
      });
    }

    // Capture the exception
    final sentryId = await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = level;
        if (message != null) {
          scope.setTag('error_message', message);
        }
      },
    );

    AppLogger.info('Error reported to Sentry', {
      'sentryId': sentryId.toString(),
      'error': error.toString(),
    });
  }

  /// Add breadcrumb for debugging
  static void addBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    if (!_initialized) return;

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Set user context for error tracking
  static Future<void> setUser({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic>? data,
  }) async {
    if (!_initialized) return;

    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: data,
      ));
    });

    AppLogger.info('User context set', {
      'userId': id,
      'username': username,
    });
  }

  /// Clear user context (e.g., on logout)
  static Future<void> clearUser() async {
    if (!_initialized) return;

    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });

    AppLogger.info('User context cleared');
  }

  /// Start a performance transaction
  static ISentrySpan? startTransaction(
    String name,
    String operation, {
    Map<String, dynamic>? data,
  }) {
    if (!_initialized) return null;

    final transaction = Sentry.startTransaction(name, operation);

    if (data != null) {
      data.forEach((key, value) {
        transaction.setData(key, value);
      });
    }

    return transaction;
  }

  /// Capture a message (non-error event)
  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? context,
  }) async {
    if (!_initialized) return;

    if (context != null) {
      await Sentry.configureScope((scope) {
        context.forEach((key, value) {
          scope.setExtra(key, value);
        });
      });
    }

    await Sentry.captureMessage(message, level: level);
  }

  /// Show user feedback dialog after an error
  static Future<void> showUserFeedbackDialog(SentryId sentryId) async {
    if (!_initialized) return;

    // In Sentry v9, user feedback is handled differently
    // You would typically use the Sentry User Feedback widget or
    // capture feedback as part of an event context
    await Sentry.captureMessage(
      'User feedback requested for event: $sentryId',
      withScope: (scope) {
        scope.setTag('feedback_event_id', sentryId.toString());
        scope.setExtra('feedback_requested', true);
      },
    );
  }

  /// Check if error tracking is initialized
  static bool get isInitialized => _initialized;

  /// Get current environment
  static String get environment => _environment;
}

/// Validation function for ErrorTrackingService
void validateErrorTrackingService() {
  AppLogger.info('Validating ErrorTrackingService...');

  // Test initialization check
  assert(!ErrorTrackingService.isInitialized,
    'Service should not be initialized before calling initialize()');

  // Test environment detection
  assert(ErrorTrackingService.environment == (kDebugMode ? 'development' : 'production'),
    'Environment should be correctly detected');

  AppLogger.info('ErrorTrackingService validation passed');
}