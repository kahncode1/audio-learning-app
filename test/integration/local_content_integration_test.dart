import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_learning_app/screens/local_content_test_screen.dart';

/// Integration test for local content loading
///
/// Purpose: Tests the download-first architecture implementation
/// This test runs with the actual app configuration and assets.
void main() {
  testWidgets('LocalContentTestScreen loads and displays test content', (WidgetTester tester) async {
    // Build the test screen
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LocalContentTestScreen(),
        ),
      ),
    );

    // Verify the screen is displayed
    expect(find.text('Local Content Test'), findsOneWidget);
    expect(find.text('Ready to load content'), findsOneWidget);

    // Find and tap the load content button
    final loadButton = find.byWidgetPredicate(
      (widget) => widget is ElevatedButton &&
          widget.child is Row &&
          (widget.child as Row).children.any((child) =>
              child is Text && child.data == 'Load Test Content'),
    );
    expect(loadButton, findsOneWidget);

    await tester.tap(loadButton);
    await tester.pump();

    // Should show loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading content...'), findsOneWidget);

    // Wait for async operations to complete
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Should show success state with content info
    expect(find.text('Content Information'), findsOneWidget);
    expect(find.text('Version: 1.0'), findsOneWidget);
    expect(find.text('Word Count: 63'), findsOneWidget);

    // Should show timing information
    expect(find.text('Timing Information'), findsOneWidget);
    expect(find.text('Words: 63'), findsOneWidget);
    expect(find.text('Sentences: 4'), findsOneWidget);

    // Should have playback controls
    expect(find.text('Playback Controls'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.replay_30), findsOneWidget);
    expect(find.byIcon(Icons.forward_30), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Speed: 1.0x'), findsOneWidget);
  });
}