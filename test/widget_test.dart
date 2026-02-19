import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heartanalysis/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Onboarding screen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const HeartStrokeApp());

    // Allow navigation from the root decider to onboarding without waiting for the infinite animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Welcome to\nHeart Stroke Prediction'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
