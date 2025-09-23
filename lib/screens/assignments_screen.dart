import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../models/learning_object.dart';
import '../providers/providers.dart';
import '../widgets/mini_audio_player.dart';

/// AssignmentsScreen displays assignments with expandable tiles
class AssignmentsScreen extends ConsumerWidget {
  final String courseNumber;
  final String courseId;
  final String courseTitle;

  const AssignmentsScreen({
    super.key,
    required this.courseNumber,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Try to get real assignments from Supabase, fallback to mock
    final assignmentsFuture = ref.watch(assignmentsProvider(courseId));

    return assignmentsFuture.when(
      data: (realAssignments) {
        final assignments = realAssignments.isNotEmpty
            ? realAssignments
            : ref.watch(mockAssignmentsProvider);

        final shouldShowMiniPlayer = ref.watch(shouldShowMiniPlayerProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(courseNumber),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView.builder(
                padding: EdgeInsets.only(
                  bottom: shouldShowMiniPlayer ? 100 : 0,
                ),
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  return AssignmentTile(
                    assignment: assignment,
                    courseNumber: courseNumber,
                    courseTitle: courseTitle,
                    initiallyExpanded: index == 0,
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  offset: shouldShowMiniPlayer ? Offset.zero : const Offset(0, 1),
                  child: const AnimatedMiniAudioPlayer(),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        // Fallback to mock data on error
        final assignments = ref.watch(mockAssignmentsProvider);
        final shouldShowMiniPlayer = ref.watch(shouldShowMiniPlayerProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(courseNumber),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
          body: Stack(
            children: [
              ListView.builder(
                padding: EdgeInsets.only(
                  bottom: shouldShowMiniPlayer ? 100 : 0,
                ),
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  return AssignmentTile(
                    assignment: assignment,
                    courseNumber: courseNumber,
                    courseTitle: courseTitle,
                    initiallyExpanded: index == 0,
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  offset: shouldShowMiniPlayer ? Offset.zero : const Offset(0, 1),
                  child: const AnimatedMiniAudioPlayer(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AssignmentTile extends ConsumerStatefulWidget {
  final Assignment assignment;
  final String courseNumber;
  final String courseTitle;
  final bool initiallyExpanded;

  const AssignmentTile({
    super.key,
    required this.assignment,
    required this.courseNumber,
    required this.courseTitle,
    required this.initiallyExpanded,
  });

  @override
  ConsumerState<AssignmentTile> createState() => _AssignmentTileState();
}

class _AssignmentTileState extends ConsumerState<AssignmentTile> {
  late bool isExpanded;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    // Try to load real learning objects from Supabase, fallback to mock
    final learningObjectsFuture = ref.watch(learningObjectsProvider(assignment.id));

    final learningObjects = learningObjectsFuture.when(
      data: (realObjects) => realObjects.isNotEmpty
          ? realObjects
          : ref.watch(mockLearningObjectsProvider(assignment.id)),
      loading: () => <LearningObject>[],
      error: (_, __) => ref.watch(mockLearningObjectsProvider(assignment.id)),
    );

    // Check if this assignment has the currently playing learning object
    final audioContext = ref.watch(audioContextProvider);
    final isActiveAssignment = audioContext != null &&
        audioContext.assignmentNumber == assignment.assignmentNumber;

    const completionPercentage = 0.0; // For now, showing 0% completion
    final String completionText = completionPercentage == 0
        ? 'Not started'
        : '${completionPercentage.round()}% complete';

    // Calculate duration based on learning objects
    final durationMinutes = learningObjects.length * 5; // Estimate 5 min per object

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: (expanded) => setState(() => isExpanded = expanded),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        leading: CircleAvatar(
          backgroundColor: isActiveAssignment || isExpanded
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Theme.of(context).dividerColor.withOpacity(0.2),
          foregroundColor: isActiveAssignment || isExpanded
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
          child: Text(
            assignment.assignmentNumber.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          assignment.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${learningObjects.length} learning objects • $durationMinutes min • $completionText',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey.shade600,
        ),
        children: learningObjects.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No learning objects available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ]
            : [
                // Add divider at the top of learning objects list
                const Divider(height: 1, thickness: 1),
                ...learningObjects.map(
                  (learningObject) => LearningObjectTile(
                    learningObject: learningObject,
                    isActive: audioContext?.learningObject.id == learningObject.id,
                    onTap: () async {
                      // Set the audio context before navigation
                      ref.read(audioContextProvider.notifier).state = AudioContext(
                        courseNumber: widget.courseNumber,
                        courseTitle: widget.courseTitle,
                        assignmentTitle: assignment.title,
                        assignmentNumber: assignment.assignmentNumber,
                        learningObject: learningObject,
                      );

                      final result = await Navigator.pushNamed(
                        context,
                        '/player',
                        arguments: {
                          'learningObject': learningObject,
                          'courseNumber': widget.courseNumber,
                          'courseTitle': widget.courseTitle,
                          'assignmentTitle': assignment.title,
                          'assignmentNumber': assignment.assignmentNumber,
                        },
                      );

                      // If the learning object was completed, refresh the list
                      if (result == true) {
                        ref.invalidate(learningObjectsProvider(assignment.id));
                      }
                    },
                  ),
                ),
              ],
      ),
    );
  }
}

class LearningObjectTile extends StatelessWidget {
  final LearningObject learningObject;
  final bool isActive;
  final VoidCallback? onTap;

  const LearningObjectTile({
    super.key,
    required this.learningObject,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = learningObject.isCompleted;
    final isInProgress = learningObject.currentPositionMs > 0 && !isCompleted;

    // Estimate duration based on content length
    final durationMinutes = ((learningObject.plainText?.length ?? 500) / 150).round();

    String statusText = '$durationMinutes min';
    if (isCompleted) {
      statusText = 'Completed • $durationMinutes min';
    } else if (isInProgress) {
      statusText = 'In Progress • $durationMinutes min';
    }

    return Container(
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF4CAF50).withOpacity(0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: Container(
          width: 40,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 4),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Icon(
                Icons.play_circle_fill,
                color: isCompleted
                    ? const Color(0xFF4CAF50)
                    : isActive
                        ? const Color(0xFF2196F3)
                        : const Color(0xFFBDBDBD),
                size: 32,
              ),
              if (isCompleted)
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF4CAF50),
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          learningObject.title,
          style: TextStyle(
            fontSize: 15,
            color: isCompleted
                ? const Color(0xFF388E3C)
                : isActive
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF424242),
            fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          statusText,
          style: TextStyle(
            fontSize: 12,
            color: isCompleted
                ? const Color(0xFF4CAF50)
                : Colors.grey.shade600,
            fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: isCompleted
            ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 24)
            : isInProgress
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Resume',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2196F3),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
        onTap: onTap,
      ),
    );
  }
}