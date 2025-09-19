/// Download Progress Screen
///
/// Purpose: Shows download progress for course content
/// Features:
/// - Real-time progress updates
/// - Current file being downloaded
/// - Overall progress with percentage and size
/// - Download speed and time remaining
/// - Retry failed downloads
/// - Pause/resume capability
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => DownloadProgressScreen(
///       courseInfo: courseInfo,
///       onComplete: () => Navigator.of(context).pop(),
///     ),
///   ),
/// );
/// ```

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/download_models.dart';
import '../services/course_download_service.dart';
import '../utils/app_logger.dart';

class DownloadProgressScreen extends StatefulWidget {
  final CourseDownloadInfo courseInfo;
  final VoidCallback? onComplete;

  const DownloadProgressScreen({
    Key? key,
    required this.courseInfo,
    this.onComplete,
  }) : super(key: key);

  @override
  State<DownloadProgressScreen> createState() => _DownloadProgressScreenState();
}

class _DownloadProgressScreenState extends State<DownloadProgressScreen>
    with SingleTickerProviderStateMixin {
  late CourseDownloadService _downloadService;
  StreamSubscription<CourseDownloadProgress?>? _progressSubscription;
  CourseDownloadProgress? _currentProgress;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeDownload();

    // Set up pulse animation for downloading indicator
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeDownload() async {
    try {
      _downloadService = await CourseDownloadService.getInstance();

      // Listen to progress updates
      _progressSubscription = _downloadService.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _currentProgress = progress;
          });

          // Check if download is complete
          if (progress?.isComplete == true && progress?.overallStatus == DownloadStatus.completed) {
            _onDownloadComplete();
          }
        }
      });

    } catch (e) {
      AppLogger.error('Failed to initialize download', error: e);
      _showError(e.toString());
    }
  }

  void _onDownloadComplete() {
    _animationController.stop();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Course downloaded successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Call completion callback after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download error: $message'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _retryDownload,
        ),
      ),
    );
  }

  Future<void> _pauseDownload() async {
    await _downloadService.pauseDownload();
  }

  Future<void> _resumeDownload() async {
    await _downloadService.resumeDownload();
  }

  Future<void> _retryDownload() async {
    await _downloadService.retryFailed();
  }

  String _getCurrentFileName() {
    if (_currentProgress == null) return '';

    final currentTask = _currentProgress!.tasks.firstWhere(
      (task) => task.status == DownloadStatus.downloading,
      orElse: () => _currentProgress!.tasks.first,
    );

    final fileName = currentTask.localPath.split('/').last;
    return 'Downloading: $fileName';
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloading = _currentProgress?.overallStatus == DownloadStatus.downloading;
    final isPaused = _currentProgress?.overallStatus == DownloadStatus.paused;
    final hasFailed = _currentProgress?.hasFailed == true;

    return WillPopScope(
      onWillPop: () async {
        // Prevent dismissing while downloading
        if (isDownloading || isPaused) {
          _showCancelConfirmation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: isDownloading ? _pulseAnimation.value : 1.0,
                            child: Icon(
                              Icons.cloud_download,
                              color: theme.primaryColor,
                              size: 32,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Downloading Course',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.courseInfo.courseName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Main progress indicator
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Circular progress
                      CircularPercentIndicator(
                        radius: 120,
                        lineWidth: 12,
                        percent: _currentProgress?.percentage ?? 0,
                        center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${((_currentProgress?.percentage ?? 0) * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                            if (_currentProgress != null)
                              Text(
                                '${_currentProgress!.completedFiles} / ${_currentProgress!.totalFiles}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        progressColor: theme.primaryColor,
                        backgroundColor: Colors.grey[200]!,
                        circularStrokeCap: CircularStrokeCap.round,
                        animation: true,
                        animationDuration: 500,
                      ),
                      const SizedBox(height: 32),

                      // Current file
                      if (_currentProgress != null && isDownloading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getCurrentFileName(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Progress details
                      if (_currentProgress != null) ...[
                        // Size progress
                        Text(
                          _currentProgress!.getProgressString(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Speed and time remaining
                        if (isDownloading) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Download speed
                              Row(
                                children: [
                                  Icon(
                                    Icons.speed,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${CourseDownloadProgress.formatBytes(_currentProgress!.getDownloadSpeed())}/s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 24),

                              // Time remaining
                              if (_currentProgress!.getEstimatedTimeRemaining() != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      CourseDownloadProgress.formatDuration(
                                        _currentProgress!.getEstimatedTimeRemaining()!,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ],

                      // Error indicator
                      if (hasFailed) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_currentProgress!.failedFiles} files failed',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pause/Resume button
                    if (isDownloading || isPaused) ...[
                      ElevatedButton.icon(
                        onPressed: isDownloading ? _pauseDownload : _resumeDownload,
                        icon: Icon(isDownloading ? Icons.pause : Icons.play_arrow),
                        label: Text(isDownloading ? 'Pause' : 'Resume'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],

                    // Retry button (for failed downloads)
                    if (hasFailed && !isDownloading)
                      ElevatedButton.icon(
                        onPressed: _retryDownload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Failed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download?'),
        content: const Text(
          'Are you sure you want to cancel the download? You can resume it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Downloading'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pauseDownload();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}