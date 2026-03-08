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
  });
}
