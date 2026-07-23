import 'package:petfy/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Petfy shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CodexPetApp());

    expect(find.byTooltip('Petfy'), findsOneWidget);
    expect(find.text('Codex Tasks'), findsNothing);
  });
}
