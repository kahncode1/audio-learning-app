import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/learning_object.dart';
import '../config/env_config.dart';

/// HomePage displays the list of available courses
/// This is a placeholder implementation for Milestone 1
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school,
              size: 80,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your courses will appear here',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Complete authentication setup to load courses',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/test-speechify');
              },
              icon: const Icon(Icons.science),
              label: const Text('Test Speechify API'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Create a test learning object
                final testLearningObject = LearningObject(
                  id: 'test-001',
                  assignmentId: 'assignment-001',
                  title: 'Test Audio Content',
                  plainText: 'This is a test of the audio playback system. '
                      'The quick brown fox jumps over the lazy dog. '
                      'Flutter provides a rich set of widgets for building beautiful UIs.',
                  orderIndex: 1,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  isCompleted: false,
                  currentPositionMs: 0,
                );

                Navigator.pushNamed(
                  context,
                  '/player',
                  arguments: testLearningObject,
                );
              },
              icon: const Icon(Icons.play_circle_filled),
              label: const Text('Test Audio Player'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  // Initialize Supabase client directly
                  final supabase = SupabaseClient(
                    EnvConfig.supabaseUrl,
                    EnvConfig.supabaseAnonKey,
                  );

                  // Fetch the test learning object directly
                  final response = await supabase
                      .from('learning_objects')
                      .select('*')
                      .eq('id', '94096d75-7125-49be-b11c-49a9d5b5660d')
                      .single();

                  // Convert response to LearningObject
                  final learningObject = LearningObject(
                    id: response['id'],
                    assignmentId: response['assignment_id'],
                    title: response['title'],
                    contentType: response['content_type'],
                    ssmlContent: response['ssml_content'],
                    plainText: response['plain_text'],
                    orderIndex: response['order_index'] ?? 1,
                    createdAt: DateTime.parse(response['created_at']),
                    updatedAt: DateTime.parse(response['updated_at']),
                    isCompleted: false,
                    currentPositionMs: 0,
                  );

                  // Close loading dialog
                  if (context.mounted) {
                    Navigator.pop(context);
                  }

                  // Navigate to player with database content
                  if (context.mounted) {
                    Navigator.pushNamed(
                      context,
                      '/player',
                      arguments: learningObject,
                    );
                  }
                } catch (e) {
                  // Close loading dialog
                  if (context.mounted) {
                    Navigator.pop(context);
                  }

                  // Show error dialog
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Error'),
                        content: Text('Failed to load test data: $e'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.storage),
              label: const Text('Test with Database'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
