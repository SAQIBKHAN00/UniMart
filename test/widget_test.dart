import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unimart/main.dart';

void main() {
  testWidgets('UniMart app initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
