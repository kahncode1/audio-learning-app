import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget with necessary providers for testing
Widget createTestWidget(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
    ),
  );
}

/// Creates a MaterialApp with the widget as home for testing
Widget createMaterialApp(Widget home) {
  return MaterialApp(
    home: home,
  );
}

/// Pumps a widget wrapped with ProviderScope and MaterialApp
Future<void> pumpTestWidget(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: widget,
      ),
    ),
  );
}
