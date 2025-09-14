import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../models/learning_object.dart';
import '../services/mock_data_service.dart';

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
    // Get test assignments from mock data
    final assignments = MockDataService.getTestAssignments();

    return Scaffold(
      appBar: AppBar(
        title: Text(courseNumber),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView.builder(
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return AssignmentTile(
            assignment: assignment,
            initiallyExpanded: index == 0, // First assignment expanded
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
  List<LearningObject> learningObjects = [];

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initiallyExpanded;
    // Load learning objects for this assignment
    learningObjects = MockDataService.getTestLearningObjects(widget.assignment.id);
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
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
        childrenPadding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE3F2FD),
          foregroundColor: const Color(0xFF2196F3),
          child: Text(
            assignment.assignmentNumber.toString(),
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
            : learningObjects
                .map(
                  (learningObject) => LearningObjectTile(
                    learningObject: learningObject,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/player',
                        arguments: learningObject,
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
    // Estimate duration based on content length
    final durationMinutes = ((learningObject.ssmlContent?.length ?? 500) / 150).round(); // Rough estimate
    String durationText = '$durationMinutes min';

    if (learningObject.currentPositionMs > 0) {
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