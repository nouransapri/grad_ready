// Widget test for GradReady app.
// Tests that the Splash screen builds and shows the main content.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grad_ready/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows GradReady title and Get Started button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    expect(find.text('GradReady'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
