import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AudioPlayerScreen provides the main audio playback interface
/// This is a placeholder implementation for Milestone 1
class AudioPlayerScreen extends ConsumerWidget {
  final String learningObjectId;
  final String title;

  const AudioPlayerScreen({
    super.key,
    required this.learningObjectId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Content area for future highlighted text
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Content will appear here',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'With dual-level word highlighting',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Player controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Progress bar
                  LinearProgressIndicator(
                    value: 0.0,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_30),
                        iconSize: 32,
                        onPressed: () {},
                        tooltip: 'Skip back 30s',
                      ),
                      FloatingActionButton(
                        onPressed: () {},
                        child: const Icon(Icons.play_arrow, size: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_30),
                        iconSize: 32,
                        onPressed: () {},
                        tooltip: 'Skip forward 30s',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Speed and font controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.speed),
                        label: const Text('1.0x'),
                        onPressed: () {},
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.text_fields),
                        label: const Text('Medium'),
                        onPressed: () {},
                      ),
                    ],
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
