import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/main.dart';
import 'package:studymate/screens/courses_screen.dart';
import 'package:studymate/screens/tasks_screen.dart';
import 'package:studymate/screens/calendar_screen.dart';
import 'package:studymate/screens/profile_screen.dart';

void main() {
  group('Navigation Tests', () {
    testWidgets('Bottom navigation bar switches between tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Verify we start on Dashboard (Home)
      expect(find.text('Good morning'), findsOneWidget);

      // Navigate to Courses tab using bottom navigation
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.menu_book_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(CoursesScreen), findsOneWidget);

      // Navigate to Tasks tab
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.task_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(TasksScreen), findsOneWidget);

      // Navigate to Calendar tab
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);

      // Navigate to Profile tab
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.person_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      // Navigate back to Home
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Good morning'), findsOneWidget);
    });

    testWidgets('Dashboard quick action buttons navigate correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Find and tap Courses quick action
      final coursesButton = find.widgetWithText(InkWell, 'Courses').first;
      await tester.ensureVisible(coursesButton);
      await tester.tap(coursesButton);
      await tester.pumpAndSettle();
      
      // Verify we're on Courses screen
      expect(find.byType(CoursesScreen), findsOneWidget);

      // Go back to home
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.home_outlined));
      await tester.pumpAndSettle();

      // Find and tap Tasks quick action
      final tasksButton = find.widgetWithText(InkWell, 'Tasks').first;
      await tester.ensureVisible(tasksButton);
      await tester.tap(tasksButton);
      await tester.pumpAndSettle();
      
      // Verify we're on Tasks screen
      expect(find.byType(TasksScreen), findsOneWidget);

      // Go back to home
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.home_outlined));
      await tester.pumpAndSettle();

      // Find and tap Calendar quick action
      final calendarButton = find.widgetWithText(InkWell, 'Calendar').first;
      await tester.ensureVisible(calendarButton);
      await tester.tap(calendarButton);
      await tester.pumpAndSettle();
      
      // Verify we're on Calendar screen
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('Dashboard section "View all" and "See all" links navigate correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Verify we're on dashboard
      expect(find.text('Good morning'), findsOneWidget);

      // Scroll to make "View all" visible and test it for courses
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, 'View all'),
        100.0,
      );
      await tester.pumpAndSettle();
      
      final viewAllCourses = find.widgetWithText(TextButton, 'View all').first;
      await tester.tap(viewAllCourses);
      await tester.pumpAndSettle();
      expect(find.byType(CoursesScreen), findsOneWidget);

      // Go back to home
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.home_outlined));
      await tester.pumpAndSettle();

      // Scroll to find and test "See all" for tasks
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, 'See all'),
        100.0,
      );
      await tester.pumpAndSettle();
      
      final seeAllTasks = find.widgetWithText(TextButton, 'See all');
      await tester.tap(seeAllTasks);
      await tester.pumpAndSettle();
      expect(find.byType(TasksScreen), findsOneWidget);

      // Go back to home
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.home_outlined));
      await tester.pumpAndSettle();

      // Scroll to find and test "Open calendar"
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, 'Open calendar'),
        100.0,
      );
      await tester.pumpAndSettle();
      
      final openCalendar = find.widgetWithText(TextButton, 'Open calendar');
      await tester.tap(openCalendar);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('Notifications button opens notifications screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Find and tap the notifications icon
      final notificationIcon = find.byIcon(Icons.notifications_none_rounded);
      await tester.tap(notificationIcon);
      await tester.pumpAndSettle();

      // Verify notifications screen opened
      expect(find.text('Notifications'), findsOneWidget);

      // Go back
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Good morning'), findsOneWidget);
    });
  });

  group('Add Button Tests', () {
    testWidgets('Floating action button opens quick create menu',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Tap the floating action button
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Create'));
      await tester.pumpAndSettle();

      // Verify quick create menu appeared
      expect(find.text('Create something'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
    });

    testWidgets('Quick create menu opens correct forms',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Test Task creation
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Task'));
      await tester.pumpAndSettle();
      expect(find.text('Task details'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Test Course creation
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Course'));
      await tester.pumpAndSettle();
      expect(find.text('Course details'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Test Note creation
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Note'));
      await tester.pumpAndSettle();
      expect(find.text('Note details'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Test Event creation
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Event'));
      await tester.pumpAndSettle();
      expect(find.text('Event details'), findsOneWidget);
    });

    testWidgets('Screen-specific add buttons open correct forms',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Navigate to Courses screen using bottom nav and test add button
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.menu_book_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Course details'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Navigate to Tasks screen and test add button
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.task_alt_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Task details'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Navigate to Calendar screen and test add button
      await tester.tap(find.widgetWithIcon(NavigationDestination, Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Event details'), findsOneWidget);
    });
  });
}
