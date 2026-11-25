import 'package:flutter_test/flutter_test.dart';
import 'package:bekal_dakwah_app/main.dart';

void main() {
  testWidgets('Bekal Dakwah smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BekalDakwahApp());
    expect(find.text('Bekal Dakwah'), findsOneWidget);
  });
}
