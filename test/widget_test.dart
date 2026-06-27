import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whispr/main.dart';

void main() {
  testWidgets('WhisprApp renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: WhisprApp()));

    // App should render a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
