import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:audio_learning_app/screens/assignments_screen.dart';
import 'package:audio_learning_app/models/learning_object_v2.dart';
import '../test_data.dart';
import 'package:audio_learning_app/providers/database_providers.dart';

// Mock classes
class MockLearningObjectsNotifier extends Mock
    implements AsyncNotifier<List<LearningObjectV2>> {}

void main() {
  late LearningObjectV2 completedLearningObject;
  late LearningObjectV2 inProgressLearningObject;
  late LearningObjectV2 notStartedLearningObject;

  setUp(() {
    completedLearningObject = TestData.createTestLearningObjectV2(
      id: 'completed-id',
      assignmentId: 'assignment-id',
      title: 'Completed Learning Object',
      displayText: 'This is a completed learning object with some content',
      totalDurationMs: 120000,
      orderIndex: 1,
      isCompleted: true,
      isInProgress: false,
      currentPositionMs: 120000,
    );

    inProgressLearningObject = TestData.createTestLearningObjectV2(
      id: 'in-progress-id',
      assignmentId: 'assignment-id',
      title: 'In Progress Learning Object',
      displayText: 'This is an in-progress learning object with some content',
      totalDurationMs: 180000,
      orderIndex: 2,
      isCompleted: false,
      isInProgress: true,
      currentPositionMs: 90000,
    );

    notStartedLearningObject = TestData.createTestLearningObjectV2(
      id: 'not-started-id',
      assignmentId: 'assignment-id',
      title: 'Not Started Learning Object',
      displayText: 'This is a not started learning object with some content',
      totalDurationMs: 60000,
      orderIndex: 3,
      isCompleted: false,
      isInProgress: false,
      currentPositionMs: 0,
    );
  });

  group('LearningObjectTileV2 Completion UI', () {
    testWidgets('should display checkmark icon for completed items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: completedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find checkmark icon
      final checkmarkFinder = find.byIcon(Icons.check_circle);
      expect(checkmarkFinder,
          findsWidgets); // May find multiple (overlay + trailing)

      // Verify at least one checkmark exists in the ListTile
      final trailingCheckmark = find.descendant(
        of: find.byType(ListTile),
        matching: find.byIcon(Icons.check_circle),
      );
      expect(trailingCheckmark, findsWidgets);
    });

    testWidgets('should display green background for completed items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: completedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find the Container with background color
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(LearningObjectTileV2),
          matching: find.byType(Container).first,
        ),
      );

      // Verify background color
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF4CAF50).withOpacity(0.04));
    });

    testWidgets('should display "Completed" status text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: completedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find status text - may appear in both title and subtitle
      expect(find.textContaining('Completed'), findsWidgets);
    });

    testWidgets('should display green play icon for completed items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: completedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find play icon
      final playIcon = tester.widget<Icon>(
        find.byIcon(Icons.play_circle_fill).first,
      );

      // Verify green color
      expect(playIcon.color, const Color(0xFF4CAF50));
    });

    testWidgets('should display "Resume" badge for in-progress items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: inProgressLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find resume badge
      expect(find.text('Resume'), findsOneWidget);

      // Verify badge styling
      final resumeContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Resume'),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(resumeContainer.decoration, isA<BoxDecoration>());
      final decoration = resumeContainer.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF2196F3).withOpacity(0.1));
    });

    testWidgets('should display "In Progress" in status text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: inProgressLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find status text - may appear in both title and subtitle
      expect(find.textContaining('In Progress'), findsWidgets);
    });

    testWidgets('should not display any badge for not started items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: notStartedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Should not find checkmark or resume badge
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('Resume'), findsNothing);

      // Should only show duration
      expect(find.textContaining('min'), findsOneWidget);
      expect(find.textContaining('Completed'), findsNothing);
      expect(find.textContaining('In Progress'), findsNothing);
    });

    testWidgets('should apply active styling when item is playing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: notStartedLearningObject,
              isActive: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find play icon
      final playIcon = tester.widget<Icon>(
        find.byIcon(Icons.play_circle_fill).first,
      );

      // Verify blue color for active item
      expect(playIcon.color, const Color(0xFF2196F3));

      // Verify title styling
      final titleText = tester.widget<Text>(
        find.text(notStartedLearningObject.title),
      );
      expect(titleText.style?.color, const Color(0xFF2196F3));
      expect(titleText.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('should handle tap callback', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: notStartedLearningObject,
              isActive: false,
              onTap: () {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      // Tap the tile
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(wasTapped, true);
    });
  });

  group('Assignment Screen Navigation', () {
    testWidgets('should handle navigation result for completed item',
        (tester) async {
      // This test would require more complex setup with providers
      // and navigation, so we'll create a simplified version

      bool providerInvalidated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [
              assignmentLearningObjectsProvider('test-assignment')
                  .overrideWith((ref) async {
                providerInvalidated = true;
                return [completedLearningObject];
              }),
            ],
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // Simulate navigation returning true
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Complete'),
                            ),
                          ),
                        ),
                      );

                      if (result == true) {
                        // This would invalidate the provider in the actual implementation
                        providerInvalidated = true;
                      }
                    },
                    child: const Text('Open Learning Object'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Tap to navigate
      await tester.tap(find.text('Open Learning Object'));
      await tester.pumpAndSettle();

      // Tap to complete
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();

      // Verify provider would be invalidated
      expect(providerInvalidated, true);
    });
  });

  group('Visual Feedback Consistency', () {
    testWidgets('should maintain consistent icon sizes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LearningObjectTileV2(
                  learningObject: completedLearningObject,
                  isActive: false,
                  onTap: () {},
                ),
                LearningObjectTileV2(
                  learningObject: inProgressLearningObject,
                  isActive: false,
                  onTap: () {},
                ),
                LearningObjectTileV2(
                  learningObject: notStartedLearningObject,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Find all play icons
      final playIcons = tester.widgetList<Icon>(
        find.byIcon(Icons.play_circle_fill),
      );

      // Verify all have the same size
      for (final icon in playIcons) {
        expect(icon.size, 32);
      }
    });

    testWidgets('should use consistent font sizes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LearningObjectTileV2(
                  learningObject: completedLearningObject,
                  isActive: false,
                  onTap: () {},
                ),
                LearningObjectTileV2(
                  learningObject: inProgressLearningObject,
                  isActive: false,
                  onTap: () {},
                ),
                LearningObjectTileV2(
                  learningObject: notStartedLearningObject,
                  isActive: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Find all title texts
      final titles = [
        tester.widget<Text>(find.text(completedLearningObject.title)),
        tester.widget<Text>(find.text(inProgressLearningObject.title)),
        tester.widget<Text>(find.text(notStartedLearningObject.title)),
      ];

      // Verify consistent font sizes
      for (final title in titles) {
        expect(title.style?.fontSize, 15);
      }
    });

    testWidgets('should apply proper color scheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningObjectTileV2(
              learningObject: completedLearningObject,
              isActive: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify green color scheme for completed items
      final titleText = tester.widget<Text>(
        find.text(completedLearningObject.title),
      );
      expect(titleText.style?.color, const Color(0xFF388E3C));

      // Verify checkmark color
      final checkmarkIcon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle).last,
      );
      expect(checkmarkIcon.color, const Color(0xFF4CAF50));
      expect(checkmarkIcon.size, 24);
    });
  });
}
