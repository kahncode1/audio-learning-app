/// Network Downloader
///
/// Purpose: Handles network operations for file downloads
/// Manages HTTP requests, streaming, and network state
///
/// Responsibilities:
/// - HTTP download operations
/// - Resume support with range requests
/// - Network connectivity checks
/// - Retry logic and error handling
/// - Bandwidth management
///
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/dio_provider.dart';
import '../../utils/app_logger.dart';

class NetworkDownloader {
  late final Dio _dio;
  final Connectivity _connectivity = Connectivity();
  CancelToken? _currentCancelToken;
  StreamSubscription? _connectivitySubscription;
  bool _wifiOnly = false;

  // Download callbacks
  void Function(int received, int total)? onProgress;
  void Function(String error)? onError;
  void Function()? onComplete;

  /// Initialize the network downloader
  void initialize({bool wifiOnly = false}) {
    _dio = DioProvider.dio;
    _wifiOnly = wifiOnly;

    if (_wifiOnly) {
      _startConnectivityMonitoring();
    }

    AppLogger.info('NetworkDownloader initialized', {
      'wifiOnly': _wifiOnly,
    });
  }

  /// Download file with resume support
  Future<void> downloadFile({
    required String url,
    required String savePath,
    required String tempPath,
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final tempFile = File(tempPath);

    // Create cancel token if not provided
    _currentCancelToken = cancelToken ?? CancelToken();

    try {
      // Check network connectivity
      if (_wifiOnly && !(await isWiFiConnected())) {
        throw DownloadException(
          'WiFi-only mode enabled but not connected to WiFi',
          DownloadErrorType.noWiFi,
        );
      }

      // Check for existing partial download
      int startByte = 0;
      if (tempFile.existsSync()) {
        startByte = await tempFile.length();
        AppLogger.info('Resuming download from byte $startByte', {
          'url': url,
        });
      }

      // Prepare headers for resume
      final headers = <String, dynamic>{};
      if (startByte > 0) {
        headers['Range'] = 'bytes=$startByte-';
      }

      // Download file
      final response = await _dio.download(
        url,
        tempPath,
        deleteOnError: false,
        cancelToken: _currentCancelToken,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 30),
        ),
        onReceiveProgress: (received, total) {
          final actualReceived = startByte + received;
          final actualTotal = startByte + (total > 0 ? total : received);

          onReceiveProgress?.call(actualReceived, actualTotal);

          // Log progress periodically
          final percentage = (actualReceived / actualTotal * 100).toInt();
          if (percentage % 10 == 0) {
            AppLogger.info('Download progress', {
              'url': url,
              'percentage': percentage,
              'received': actualReceived,
              'total': actualTotal,
            });
          }
        },
      );

      // Check response status
      if (response.statusCode == 200 || response.statusCode == 206) {
        // Move temp file to final location
        if (tempFile.existsSync()) {
          await tempFile.rename(savePath);
        }

        onComplete?.call();
        AppLogger.info('Download completed', {
          'url': url,
          'savePath': savePath,
        });
      } else {
        throw DownloadException(
          'Unexpected status code: ${response.statusCode}',
          DownloadErrorType.httpError,
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        AppLogger.info('Download cancelled', {'url': url});
        throw DownloadException(
            'Download cancelled', DownloadErrorType.cancelled);
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        AppLogger.error('Download timeout', error: e);
        throw DownloadException('Download timeout', DownloadErrorType.timeout);
      } else if (e.type == DioExceptionType.connectionError) {
        AppLogger.error('Connection error', error: e);
        throw DownloadException(
            'Connection error', DownloadErrorType.networkError);
      } else {
        AppLogger.error('Download failed', error: e);
        throw DownloadException(
            e.message ?? 'Download failed', DownloadErrorType.unknown);
      }
    } catch (e) {
      AppLogger.error('Unexpected download error', error: e);
      onError?.call(e.toString());
      rethrow;
    }
  }

  /// Cancel current download
  void cancelDownload() {
    if (_currentCancelToken != null && !_currentCancelToken!.isCancelled) {
      _currentCancelToken!.cancel('User cancelled');
      _currentCancelToken = null;
    }
  }

  /// Check if connected to WiFi
  Future<bool> isWiFiConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result == ConnectivityResult.wifi);
  }

  /// Check general network connectivity
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) =>
        result != ConnectivityResult.none &&
        result != ConnectivityResult.bluetooth);
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (_wifiOnly && !results.contains(ConnectivityResult.wifi)) {
          // Pause downloads if WiFi disconnected
          cancelDownload();
          AppLogger.warning('WiFi disconnected, download paused');
        }
      },
    );
  }

  /// Test URL availability
  Future<bool> testUrl(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.warning('URL test failed',
          {'url': url, 'error': e.toString()});
      return false;
    }
  }

  /// Get file size from URL
  Future<int?> getFileSize(String url) async {
    try {
      final response = await _dio.head(url);
      final contentLength = response.headers.value('content-length');

      if (contentLength != null) {
        return int.tryParse(contentLength);
      }
    } catch (e) {
      AppLogger.warning('Failed to get file size', {'url': url});
    }
    return null;
  }

  /// Check if server supports resume
  Future<bool> supportsResume(String url) async {
    try {
      final response = await _dio.head(url);
      final acceptRanges = response.headers.value('accept-ranges');
      return acceptRanges == 'bytes';
    } catch (e) {
      AppLogger.warning('Failed to check resume support', {'url': url});
      return false;
    }
  }

  /// Update WiFi-only setting
  void updateWiFiOnly(bool wifiOnly) {
    _wifiOnly = wifiOnly;

    if (_wifiOnly && _connectivitySubscription == null) {
      _startConnectivityMonitoring();
    } else if (!_wifiOnly && _connectivitySubscription != null) {
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
    }
  }

  /// Clean up resources
  void dispose() {
    cancelDownload();
    _connectivitySubscription?.cancel();
  }
}

/// Download exception class
class DownloadException implements Exception {
  final String message;
  final DownloadErrorType type;

  DownloadException(this.message, this.type);

  @override
  String toString() => 'DownloadException: $message (type: $type)';
}

/// Download error types
enum DownloadErrorType {
  networkError,
  httpError,
  timeout,
  noWiFi,
  cancelled,
  fileSystem,
  unknown,
}
