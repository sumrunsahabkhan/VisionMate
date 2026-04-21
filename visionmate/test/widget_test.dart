import 'package:flutter_test/flutter_test.dart';
import 'package:visionmate/main.dart';

void main() {
  testWidgets('VisionMate App Smoke Test', (WidgetTester tester) async {
    // 🔥 FIXED: Renamed visionmate() to VisionMateApp() to match your lib/main.dart
    await tester.pumpWidget(const VisionMateApp());
    expect(find.byType(VisionMateApp), findsOneWidget);
  });
}
