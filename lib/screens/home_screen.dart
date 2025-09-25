import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../providers/database_providers.dart';
import '../providers/audio_providers.dart';
import '../utils/app_logger.dart';
import '../widgets/animated_loading_indicator.dart';
import '../widgets/animated_card.dart';

/// HomePage displays the list of available courses with gradient cards
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {

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
                    Text(
                      'No courses available',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your courses will appear here',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: shouldShowMiniPlayer
                      ? 116
                      : 16, // Add space for mini player
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
          child: AnimatedLoadingIndicator(
            message: 'Loading courses...',
          ),
        ),
        error: (error, stack) => Center(
          child: Text('Error loading courses: $error'),
        ),
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

    return AnimatedCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      elevation: 3,
      borderRadius: 12,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: completionPercentage / 100,
                    minHeight: 4,
                    color: completionPercentage == 0
                        ? Theme.of(context).dividerColor.withValues(alpha: 0.3)
                        : Colors.green,
                    backgroundColor:
                        Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
    );
  }
}
