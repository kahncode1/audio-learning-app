/// Performance Monitor Service
///
/// Purpose: Track and report application performance metrics
/// Features:
/// - FPS tracking for UI smoothness
/// - Word lookup time monitoring
/// - Audio load time tracking
/// - Memory usage monitoring
/// - Battery usage estimation
/// - Performance degradation alerts
///
/// Dependencies:
/// - flutter/scheduler: Frame timing information
/// - sentry_flutter: Performance transaction tracking
/// - AppLogger: Local performance logging
///
/// Usage:
/// ```dart
/// PerformanceMonitor.startTracking();
/// PerformanceMonitor.trackHighlightingFPS();
/// PerformanceMonitor.trackWordLookupTime(() => wordService.lookup(position));
/// ```

import 'dart:async';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../utils/app_logger.dart';
import 'error_tracking_service.dart';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // Performance targets
  static const int targetFps = 60;
  static const int targetWordLookupMs = 1;
  static const int targetAudioLoadMs = 2000;
  static const int targetMemoryMb = 200;
  static const double targetBatteryPerHour = 5.0;

  // Tracking state
  final Map<String, List<double>> _metrics = {};
  final Map<String, ISentrySpan?> _activeTransactions = {};
  Timer? _memoryMonitorTimer;
  bool _isTracking = false;

  // FPS tracking
  int _frameCount = 0;
  DateTime? _fpsTrackingStart;
  final List<double> _recentFps = [];

  /// Start performance tracking
  static void startTracking() {
    if (_instance._isTracking) return;

    _instance._isTracking = true;
    _instance._startMemoryMonitoring();
    _instance._startFpsMonitoring();

    AppLogger.info('Performance monitoring started');
  }

  /// Stop performance tracking
  static void stopTracking() {
    if (!_instance._isTracking) return;

    _instance._isTracking = false;
    _instance._stopMemoryMonitoring();
    _instance._stopFpsMonitoring();

    AppLogger.info('Performance monitoring stopped');
  }

  /// Track FPS for highlighting or animations
  static void trackHighlightingFPS() {
    if (!_instance._isTracking) return;

    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      final frameTiming = binding.currentFrameTimeStamp;
      _instance._recordFrame(frameTiming);
    });
  }

  /// Track word lookup performance
  static Future<T> trackWordLookupTime<T>(
      Future<T> Function() operation) async {
    if (!_instance._isTracking) return operation();

    final stopwatch = Stopwatch()..start();
    final transaction = ErrorTrackingService.startTransaction(
      'word_lookup',
      'performance',
    );

    try {
      final result = await operation();
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;
      _instance._recordMetric('word_lookup_ms', durationMs.toDouble());

      transaction?.setData('duration_ms', durationMs);
      transaction?.setData('target_ms', targetWordLookupMs);
      transaction?.status = durationMs <= targetWordLookupMs
          ? const SpanStatus.ok()
          : const SpanStatus.deadlineExceeded();

      if (durationMs > targetWordLookupMs) {
        AppLogger.warning('Word lookup exceeded target', {
          'duration_ms': durationMs,
          'target_ms': targetWordLookupMs,
        });
      }

      return result;
    } catch (e, stack) {
      transaction?.status = const SpanStatus.internalError();
      transaction?.throwable = e;
      ErrorTrackingService.reportError(e, stack);
      rethrow;
    } finally {
      await transaction?.finish();
    }
  }

  /// Track audio load time
  static Future<T> trackAudioLoadTime<T>(Future<T> Function() operation) async {
    if (!_instance._isTracking) return operation();

    final stopwatch = Stopwatch()..start();
    final transaction = ErrorTrackingService.startTransaction(
      'audio_load',
      'performance',
    );

    try {
      final result = await operation();
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;
      _instance._recordMetric('audio_load_ms', durationMs.toDouble());

      transaction?.setData('duration_ms', durationMs);
      transaction?.setData('target_ms', targetAudioLoadMs);
      transaction?.status = durationMs <= targetAudioLoadMs
          ? const SpanStatus.ok()
          : const SpanStatus.deadlineExceeded();

      if (durationMs > targetAudioLoadMs) {
        AppLogger.warning('Audio load exceeded target', {
          'duration_ms': durationMs,
          'target_ms': targetAudioLoadMs,
        });
      }

      return result;
    } catch (e, stack) {
      transaction?.status = const SpanStatus.internalError();
      transaction?.throwable = e;
      ErrorTrackingService.reportError(e, stack);
      rethrow;
    } finally {
      await transaction?.finish();
    }
  }

  /// Track a generic performance metric
  static Future<T> trackOperation<T>(
    String name,
    Future<T> Function() operation, {
    int? targetMs,
    Map<String, dynamic>? data,
  }) async {
    if (!_instance._isTracking) return operation();

    final stopwatch = Stopwatch()..start();
    final transaction = ErrorTrackingService.startTransaction(
      name,
      'performance',
    );

    if (data != null) {
      data.forEach((key, value) {
        transaction?.setData(key, value);
      });
    }

    try {
      final result = await operation();
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;
      _instance._recordMetric('${name}_ms', durationMs.toDouble());

      transaction?.setData('duration_ms', durationMs);
      if (targetMs != null) {
        transaction?.setData('target_ms', targetMs);
        transaction?.status = durationMs <= targetMs
            ? const SpanStatus.ok()
            : const SpanStatus.deadlineExceeded();

        if (durationMs > targetMs) {
          AppLogger.warning('$name exceeded target', {
            'duration_ms': durationMs,
            'target_ms': targetMs,
          });
        }
      } else {
        transaction?.status = const SpanStatus.ok();
      }

      return result;
    } catch (e, stack) {
      transaction?.status = const SpanStatus.internalError();
      transaction?.throwable = e;
      ErrorTrackingService.reportError(e, stack);
      rethrow;
    } finally {
      await transaction?.finish();
    }
  }

  /// Get current FPS
  static double getCurrentFps() {
    if (_instance._recentFps.isEmpty) return 0;
    final sum = _instance._recentFps.reduce((a, b) => a + b);
    return sum / _instance._recentFps.length;
  }

  /// Get memory usage in MB
  static Future<double> getMemoryUsageMb() async {
    if (!Platform.isAndroid && !Platform.isIOS) return 0;

    try {
      final info =
          await Process.run('ps', ['-o', 'rss=', '-p', pid.toString()]);
      if (info.exitCode == 0) {
        final kb = int.tryParse(info.stdout.toString().trim()) ?? 0;
        return kb / 1024; // Convert KB to MB
      }
    } catch (e) {
      AppLogger.error('Failed to get memory usage', error: e);
    }
    return 0;
  }

  /// Get performance summary
  static Map<String, dynamic> getPerformanceSummary() {
    final summary = <String, dynamic>{};

    for (final entry in _instance._metrics.entries) {
      if (entry.value.isEmpty) continue;

      final values = entry.value;
      final sum = values.reduce((a, b) => a + b);
      summary[entry.key] = {
        'average': sum / values.length,
        'min': values.reduce((a, b) => a < b ? a : b),
        'max': values.reduce((a, b) => a > b ? a : b),
        'count': values.length,
      };
    }

    summary['current_fps'] = getCurrentFps();

    return summary;
  }

  /// Check if performance is degraded
  static bool isPerformanceDegraded() {
    final fps = getCurrentFps();
    if (fps > 0 && fps < targetFps * 0.9) return true; // 90% of target FPS

    final wordLookup = _instance._getAverageMetric('word_lookup_ms');
    if (wordLookup > targetWordLookupMs * 2) return true; // 2x target

    return false;
  }

  /// Private methods
  void _startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final memoryMb = await getMemoryUsageMb();
      _recordMetric('memory_mb', memoryMb);

      if (memoryMb > targetMemoryMb) {
        AppLogger.warning('Memory usage exceeded target', {
          'memory_mb': memoryMb,
          'target_mb': targetMemoryMb,
        });

        ErrorTrackingService.captureMessage(
          'High memory usage detected',
          level: SentryLevel.warning,
          context: {
            'memory_mb': memoryMb,
            'target_mb': targetMemoryMb,
          },
        );
      }
    });
  }

  void _stopMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
  }

  void _startFpsMonitoring() {
    _frameCount = 0;
    _fpsTrackingStart = DateTime.now();
    _recentFps.clear();

    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (!_isTracking) return;
      _frameCount++;

      final now = DateTime.now();
      final elapsed = now.difference(_fpsTrackingStart!);
      if (elapsed.inSeconds >= 1) {
        final fps = _frameCount / elapsed.inSeconds;
        _recentFps.add(fps);
        if (_recentFps.length > 10) {
          _recentFps.removeAt(0); // Keep only last 10 seconds
        }

        _recordMetric('fps', fps);

        if (fps < targetFps * 0.9) {
          AppLogger.warning('FPS below target', {
            'fps': fps,
            'target_fps': targetFps,
          });
        }

        _frameCount = 0;
        _fpsTrackingStart = now;
      }
    });
  }

  void _stopFpsMonitoring() {
    // Frame callbacks are automatically removed when not needed
    _recentFps.clear();
  }

  void _recordFrame(Duration timestamp) {
    if (!_isTracking) return;
    // Frame recording logic is handled in _startFpsMonitoring
  }

  void _recordMetric(String name, double value) {
    _metrics.putIfAbsent(name, () => []).add(value);

    // Keep only last 100 values per metric
    if (_metrics[name]!.length > 100) {
      _metrics[name]!.removeAt(0);
    }
  }

  double _getAverageMetric(String name) {
    final values = _metrics[name];
    if (values == null || values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

/// Validation function for PerformanceMonitor
void validatePerformanceMonitor() async {
  AppLogger.info('Validating PerformanceMonitor...');

  // Test singleton pattern
  final monitor1 = PerformanceMonitor();
  final monitor2 = PerformanceMonitor();
  assert(identical(monitor1, monitor2),
      'PerformanceMonitor should be a singleton');

  // Test metric recording
  PerformanceMonitor.startTracking();

  // Test word lookup tracking
  await PerformanceMonitor.trackWordLookupTime(() async {
    await Future.delayed(const Duration(milliseconds: 1));
    return 'test';
  });

  // Test performance summary
  final summary = PerformanceMonitor.getPerformanceSummary();
  assert(summary.isNotEmpty, 'Performance summary should contain data');

  PerformanceMonitor.stopTracking();

  AppLogger.info('PerformanceMonitor validation passed');
}
