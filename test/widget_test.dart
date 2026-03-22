// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    // Keep this as a minimal smoke test; app boot requires Firebase init.
    await tester.pumpWidget(const TestPlaceholderApp());
    expect(find.byType(TestPlaceholderApp), findsOneWidget);
  });
}

class TestPlaceholderApp extends StatelessWidget {
  const TestPlaceholderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
