import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stat_trac_technical/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StatTracApp()));
    await tester.pumpAndSettle();
    expect(find.byType(StatTracApp), findsOneWidget);
  });
}
