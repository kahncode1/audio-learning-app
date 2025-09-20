import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../providers/mock_data_provider.dart';
import '../providers/audio_providers.dart';

/// HomePage displays the list of available courses with gradient cards
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the test course from mock data provider
    final testCourse = ref.watch(mockCourseProvider);
    final courses = [testCourse]; // List with our test course
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
      body: courses.isEmpty
          ? const Center(
              child: Text('No courses available'),
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
    final completionPercentage = ref.watch(mockCourseCompletionProvider);
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
                    '${ref.watch(mockAssignmentCountProvider)} Assignments • ${ref.watch(mockLearningObjectCountProvider)} Learning Objects',
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
