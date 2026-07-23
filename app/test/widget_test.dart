import 'package:petfy/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('shows the Petfy shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CodexPetApp());

    expect(find.byTooltip('Petfy'), findsOneWidget);
    expect(find.text('Codex Tasks'), findsNothing);
  });

  testWidgets('packages every pug mood asset', (WidgetTester tester) async {
    for (final asset in const [
      'assets/pug/pug-idle.png',
      'assets/pug/pug-working.png',
      'assets/pug/pug-completed.png',
      'assets/pug/pug-attention.png',
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0));
    }
  });
}
