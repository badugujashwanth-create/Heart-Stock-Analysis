import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('renders main navigation tabs', (tester) async {
    await tester.pumpWidget(const HeartAnalysisApp());
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsAtLeastNWidgets(1));
    expect(find.text('Report'), findsAtLeastNWidgets(1));
    expect(find.text('History'), findsAtLeastNWidgets(1));
    expect(find.text('What-If'), findsAtLeastNWidgets(1));
    expect(find.text('Assistant'), findsAtLeastNWidgets(1));
    expect(find.text('Synthetic data only.'), findsNothing);
    expect(find.textContaining('Synthetic data only.'), findsOneWidget);
  });

  testWidgets('loads the deterministic synthetic profile', (tester) async {
    await tester.pumpWidget(const HeartAnalysisApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load synthetic example'));
    await tester.pump();

    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields.first.controller?.text, '56');
    expect(fields[1].controller?.text, '148');
    expect(
      find.text('Synthetic example loaded. No real patient data is used.'),
      findsOneWidget,
    );
  });
}
