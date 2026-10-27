import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studymate/main.dart';

void main() {
  testWidgets('dashboard shortcuts open their matching pages', (tester) async {
    await tester.pumpWidget(const StudyMateApp());

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Courses'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Courses'), findsWidgets);
    expect(find.text('CS 204'), findsOneWidget);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    navigationBar.onDestinationSelected!(0);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('See all'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('To Do'), findsOneWidget);
  });

  testWidgets('notification controls open the notification page', (
    tester,
  ) async {
    await tester.pumpWidget(const StudyMateApp());

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Deadline coming up'), findsOneWidget);
  });
}
