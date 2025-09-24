import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/course.dart';
import '../providers/database_providers.dart';
import '../providers/audio_providers.dart';
import '../utils/app_logger.dart';

/// HomePage displays the list of available courses with gradient cards
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isDownloading = false;
  String _downloadStatus = '';
  double _downloadProgress = 0.0;
  bool _isDeleting = false;

  Future<void> _deleteAllDownloads() async {
    setState(() {
      _isDeleting = true;
      _downloadStatus = 'Deleting downloads...';
    });

    try {
      // Get the local database service
      final localDb = ref.read(localDatabaseServiceProvider);

      // Clear all courses, assignments, and learning objects from database
      await localDb.deleteAllCourses();

      // Also delete downloaded files
      final documentsDir = await getApplicationDocumentsDirectory();
      final audioLearningDir = Directory('${documentsDir.path}/audio_learning');
      if (await audioLearningDir.exists()) {
        await audioLearningDir.delete(recursive: true);
        AppLogger.info('Deleted all downloaded content files');
      }

      // Refresh the courses list
      ref.invalidate(localCoursesProvider);

      if (mounted) {
        setState(() {
          _isDeleting = false;
          _downloadStatus = 'All downloads deleted!';
        });

        // Clear status after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _downloadStatus = '';
            });
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All downloads deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to delete downloads', error: e);
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _downloadStatus = 'Failed to delete downloads';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete downloads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadTestCourse() async {
    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Initializing download...';
    });

    try {
      // Get the download service
      final downloadService = ref.read(courseDownloadApiServiceProvider);

      // Use a real course ID from Supabase (Insurance Fundamentals - INS-101)
      const testCourseId = 'cb236d98-dbb8-4810-b205-17e8091dcf69';
      const testUserId = 'test-user-001';

      // Listen to download progress
      downloadService.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress.percentage / 100;
            final percentage = progress.percentage.toStringAsFixed(0);
            _downloadStatus = '${progress.message ?? "Downloading"} ($percentage%)';
          });
        }
      });

      // Start the download
      await downloadService.downloadCourse(
        courseId: testCourseId,
        userId: testUserId,
      );

      // Refresh the courses list
      ref.invalidate(localCoursesProvider);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = 'Download complete!';
          _downloadProgress = 1.0;
        });

        // Clear status after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _downloadStatus = '';
              _downloadProgress = 0.0;
            });
          }
        });
      }
    } catch (e) {
      AppLogger.error('Failed to download test course', error: e);
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = 'Download failed: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download course: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get courses from local database
    final coursesAsync = ref.watch(localCoursesProvider);
    final shouldShowMiniPlayer = ref.watch(shouldShowMiniPlayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu, size: 24),
            SizedBox(width: 12),
            Text('My Courses'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: coursesAsync.when(
        data: (courses) => courses.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No courses available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Download a course to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_downloadStatus.isNotEmpty) ...[
                      Text(
                        _downloadStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isDownloading)
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _downloadTestCourse,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(_isDownloading ? 'Downloading...' : 'Download Test Course'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: shouldShowMiniPlayer ? 116 : 16, // Add space for mini player
              ),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CourseCard(
                    course: course,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/assignments',
                      arguments: {
                        'courseNumber': course.courseNumber,
                        'courseId': course.id,
                        'courseTitle': course.title,
                      },
                    ),
                  ),
                );
              },
            ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error loading courses: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isDeleting ? null : _deleteAllDownloads,
        backgroundColor: Colors.red,
        icon: _isDeleting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.delete_forever),
        label: Text(_isDeleting ? 'Deleting...' : 'Delete Downloads'),
      ),
    );
  }
}

class CourseCard extends ConsumerWidget {
  final Course course;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get course completion percentage from database
    final completionAsync = ref.watch(courseCompletionProvider(course.id));
    final completionPercentage = completionAsync.value ?? 0.0;
    final String progressLabel = completionPercentage == 0
        ? 'Not Started'
        : '${completionPercentage.round()}% Complete';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top gradient bar
            Container(
              height: 4,
              decoration: BoxDecoration(gradient: course.gradient),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.courseNumber,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${course.totalAssignments} Assignments • ${course.totalLearningObjects} Learning Objects',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progressLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: completionPercentage / 100,
                      minHeight: 4,
                      color: completionPercentage == 0
                          ? Theme.of(context).dividerColor.withOpacity(0.3)
                          : Colors.green,
                      backgroundColor: Theme.of(context).dividerColor.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
