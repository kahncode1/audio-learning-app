/// CDN Download Test Screen
///
/// Purpose: Test the download-first architecture with Supabase CDN URLs
/// This screen simulates CDN content by serving local test files and
/// allows testing the full download and offline playback flow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/course_download_service.dart';
import '../models/learning_object.dart';
import '../models/download_models.dart';
import '../utils/app_logger.dart';
import '../screens/local_content_test_screen.dart';

class CDNDownloadTestScreen extends ConsumerStatefulWidget {
  const CDNDownloadTestScreen({super.key});

  @override
  ConsumerState<CDNDownloadTestScreen> createState() => _CDNDownloadTestScreenState();
}

class _CDNDownloadTestScreenState extends ConsumerState<CDNDownloadTestScreen> {
  CourseDownloadService? _downloadService;
  CourseDownloadProgress? _downloadProgress;
  bool _isInitialized = false;
  bool _hasSimulatedUpload = false;
  bool _isDownloading = false;
  String _statusMessage = 'Initializing...';

  // Test learning object
  final testLearningObject = LearningObject(
    id: '63ad7b78-0970-4265-a4fe-51f3fee39d5f',
    title: 'Establishing a Case Reserve - Full Lesson',
    assignmentId: 'assignment456',
    orderIndex: 1,
    ssmlContent: '', // Not used in download-first architecture
    wordTimings: [], // Will be loaded from timing.json
    isInProgress: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _statusMessage = 'Initializing download service...';
      });

      _downloadService = await CourseDownloadService.getInstance();

      // Listen to download progress
      _downloadService!.progressStream.listen((progress) {
        setState(() {
          _downloadProgress = progress;
          if (progress != null) {
            _statusMessage = 'Download: ${progress.getProgressString()}';
          }
        });
      });

      setState(() {
        _isInitialized = true;
        _statusMessage = 'Ready to test CDN download';
      });

      // Check if we already have downloaded files
      await _checkExistingDownloads();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: $e';
      });
      AppLogger.error('Failed to initialize services', error: e);
    }
  }

  Future<void> _checkExistingDownloads() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final courseDir = Directory('${appDir.path}/courses/INS-101/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f');

      if (courseDir.existsSync()) {
        final audioFile = File('${courseDir.path}/audio.mp3');
        final contentFile = File('${courseDir.path}/content.json');
        final timingFile = File('${courseDir.path}/timing.json');

        if (audioFile.existsSync() && contentFile.existsSync() && timingFile.existsSync()) {
          setState(() {
            _statusMessage = 'Downloaded content found! Ready to play offline.';
          });
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to check existing downloads', {'error': e.toString()});
    }
  }

  Future<void> _simulateCDNUpload() async {
    setState(() {
      _statusMessage = 'Simulating CDN upload by copying local files...';
    });

    try {
      // Copy test files to a temporary location that simulates CDN
      final appDir = await getApplicationDocumentsDirectory();
      final cdnSimDir = Directory('${appDir.path}/cdn_simulation/INS-101/63ad7b78-0970-4265-a4fe-51f3fee39d5f');
      await cdnSimDir.create(recursive: true);

      // Note: In a real scenario, these would be uploaded to Supabase Storage
      // For testing, we'll just mark them as "uploaded" in our local simulation

      setState(() {
        _hasSimulatedUpload = true;
        _statusMessage = 'CDN simulation ready! Files are "uploaded" (simulated).';
      });

      AppLogger.info('CDN upload simulated', {
        'path': cdnSimDir.path,
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error simulating upload: $e';
      });
      AppLogger.error('Failed to simulate CDN upload', error: e);
    }
  }

  Future<void> _startDownload() async {
    if (_downloadService == null || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Starting download from CDN URLs...';
    });

    try {
      // The download service will fetch CDN URLs from the database
      // These are already configured to point to Supabase Storage
      await _downloadService!.downloadCourse(
        'INS-101',
        'Insurance Case Management',
        [testLearningObject],
      );

      setState(() {
        _statusMessage = 'Download started! Check progress above.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Download error: $e';
        _isDownloading = false;
      });
      AppLogger.error('Failed to start download', error: e);
    }
  }

  Future<void> _testOfflinePlayback() async {
    try {
      setState(() {
        _statusMessage = 'Testing offline playback...';
      });

      // Navigate to the local content test screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LocalContentTestScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Playback error: $e';
      });
    }
  }

  Future<void> _clearDownloads() async {
    try {
      setState(() {
        _statusMessage = 'Clearing downloaded files...';
      });

      final appDir = await getApplicationDocumentsDirectory();
      final courseDir = Directory('${appDir.path}/courses');

      if (courseDir.existsSync()) {
        await courseDir.delete(recursive: true);
      }

      setState(() {
        _downloadProgress = null;
        _isDownloading = false;
        _statusMessage = 'Downloads cleared. Ready to test again.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error clearing downloads: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CDN Download Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.contains('Error') ? Colors.red : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Download Progress Card
            if (_downloadProgress != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Download Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _downloadProgress!.completedFiles / (_downloadProgress!.totalFiles > 0 ? _downloadProgress!.totalFiles : 1),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _downloadProgress!.hasFailed ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _downloadProgress!.getProgressString(),
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_downloadProgress!.downloadedBytes > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Downloaded: ${(_downloadProgress!.downloadedBytes / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // CDN Configuration Info
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CDN Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Bucket: course-audio, course-content, course-timing',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Project: cmjdciktvfxiyapdseqn',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Learning Object: 63ad7b78-0970-4265-a4fe-51f3fee39d5f',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Action Buttons
            if (_isInitialized) ...[
              ElevatedButton.icon(
                onPressed: _hasSimulatedUpload ? null : _simulateCDNUpload,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_hasSimulatedUpload ? 'CDN Ready (Simulated)' : 'Simulate CDN Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasSimulatedUpload ? Colors.green : Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: (_isDownloading || !_hasSimulatedUpload) ? null : _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download from CDN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: (_downloadProgress?.isComplete ?? false) ? _testOfflinePlayback : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Test Offline Playback'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _clearDownloads,
                icon: const Icon(Icons.delete),
                label: const Text('Clear Downloads'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              'Note: Since we\'re using mock auth, this simulates the CDN flow locally.\n'
              'Real CDN URLs are configured in the database and ready for use.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}