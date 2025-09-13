# /implementations/assignments-page.dart

```dart
/// Assignments Page - Course Content with Expandable Tiles
/// 
/// Displays assignments with:
/// - Expandable ExpansionTile components
/// - CircleAvatar for assignment numbers
/// - Learning object tiles with play icons
/// - Progress and completion indicators
/// - Auto-expand first assignment

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_learning_app/models/assignment.dart';
import 'package:audio_learning_app/models/learning_object.dart';
import 'package:audio_learning_app/screens/player_page.dart';

class AssignmentsPage extends ConsumerWidget {
  final String courseNumber;
  final String courseId;
  
  const AssignmentsPage({
    super.key,
    required this.courseNumber,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(assignmentsProvider(courseId));

    return Scaffold(
      appBar: AppBar(
        title: Text(courseNumber),
      ),
      body: assignments.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorWidget(err),
        data: (assignmentList) {
          return ListView.builder(
            itemCount: assignmentList.length,
            itemBuilder: (context, index) {
              final assignment = assignmentList[index];
              return AssignmentTile(
                assignment: assignment,
                initiallyExpanded: index == 0, // First assignment expanded
              );
            },
          );
        },
      ),
    );
  }
}

class AssignmentTile extends ConsumerStatefulWidget {
  final Assignment assignment;
  final bool initiallyExpanded;

  const AssignmentTile({
    super.key,
    required this.assignment,
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
    final String completionText = assignment.completionPercentage == 0
        ? 'Not started'
        : '${assignment.completionPercentage.round()}% complete';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: (expanded) => setState(() => isExpanded = expanded),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE3F2FD),
          foregroundColor: const Color(0xFF2196F3),
          child: Text(
            assignment.number.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          assignment.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121),
          ),
        ),
        subtitle: Text(
          '${assignment.learningObjectCount} learning objects • ${assignment.durationMinutes} min • $completionText',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey.shade600,
        ),
        children: assignment.learningObjects.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Loading learning objects...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ]
            : assignment.learningObjects
                .map(
                  (learningObject) => LearningObjectTile(
                    learningObject: learningObject,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerPage(
                            learningObject: learningObject,
                          ),
                        ),
                      );
                    },
                  ),
                )
                .toList(),
      ),
    );
  }
}

class LearningObjectTile extends StatelessWidget {
  final LearningObject learningObject;
  final VoidCallback? onTap;

  const LearningObjectTile({
    super.key,
    required this.learningObject,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String durationText = '${learningObject.durationMinutes} min';
    if (learningObject.isInProgress) {
      durationText += ' • In Progress';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: const Icon(
        Icons.play_circle_fill,
        color: Color(0xFF2196F3),
        size: 32,
      ),
      title: Text(
        learningObject.title,
        style: const TextStyle(fontSize: 15, color: Color(0xFF424242)),
      ),
      subtitle: Text(
        durationText,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: learningObject.isCompleted
          ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20)
          : null,
      onTap: onTap,
    );
  }
}
```