import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/main.dart';

void main() {
  testWidgets('Sri Lankan Travel App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SriLankanTravelApp());

    // Verify that "Ayubowan!" is displayed
    expect(find.text('Ayubowan!'), findsOneWidget);
  });
}
