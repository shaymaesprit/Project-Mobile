import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/main.dart';
import 'package:studymate/screens/courses_screen.dart';
import 'package:studymate/screens/tasks_screen.dart';
import 'package:studymate/screens/calendar_screen.dart';
import 'package:studymate/screens/profile_screen.dart';

void main() {
  group('Simple Navigation Tests', () {
    testWidgets('App loads and shows dashboard', (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
    });

    testWidgets('Bottom navigation works', (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Navigate using NavigationDestination icons
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.menu_book_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(CoursesScreen), findsOneWidget);

      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.task_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(TasksScreen), findsOneWidget);

      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);

      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.person_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Good morning'), findsOneWidget);
    });

    testWidgets('FAB opens create menu', (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Create something'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
    });

    testWidgets('Profile screen scrolls properly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.person_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
