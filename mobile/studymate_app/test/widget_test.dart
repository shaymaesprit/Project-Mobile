import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/main.dart';

void main() {
  testWidgets('requires Firebase configuration before account access', (
    tester,
  ) async {
    await tester.pumpWidget(
      const StudyMateApp(
        missingFirebaseOptions: ['STUDYMATE_FIREBASE_API_KEY'],
      ),
    );

    expect(find.text('Firebase n’est pas configuré'), findsOneWidget);
    expect(find.textContaining('STUDYMATE_FIREBASE_API_KEY'), findsOneWidget);
  });
}
