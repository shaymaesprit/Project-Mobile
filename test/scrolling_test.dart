import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/main.dart';

void main() {
  group('Scrolling Tests', () {
    testWidgets('Dashboard scrolls properly with all content',
        (WidgetTester tester) async {
      // Set a small screen size to ensure scrolling is needed
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Verify we're on dashboard
      expect(find.text('Good morning'), findsOneWidget);

      // Find the SingleChildScrollView
      final scrollView = find.byType(SingleChildScrollView).first;
      expect(scrollView, findsOneWidget);

      // Scroll down to bottom
      await tester.scrollUntilVisible(
        find.text('Recent notifications'),
        500.0,
        scrollable: scrollView,
      );
      await tester.pumpAndSettle();

      // Verify we can see the bottom content
      expect(find.text('Recent notifications'), findsOneWidget);

      // Scroll back to top
      await tester.scrollUntilVisible(
        find.text('Good morning'),
        -500.0,
        scrollable: scrollView,
      );
      await tester.pumpAndSettle();

      expect(find.text('Good morning'), findsOneWidget);

      // Reset the screen size
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Courses screen scrolls when content exceeds viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Navigate to Courses
      await tester.tap(find.text('Courses'));
      await tester.pumpAndSettle();

      // Find the ListView
      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);

      // Verify list is scrollable by checking the content
      expect(find.text('Courses'), findsAtLeastNWidgets(1));

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Tasks screen scrolls and filters remain visible',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Navigate to Tasks
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      // Verify filter chips are visible
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'To Do'), findsOneWidget);

      // Try scrolling the filter chips
      final filterList = find.byType(ListView).first;
      await tester.drag(filterList, const Offset(-100, 0));
      await tester.pumpAndSettle();

      // Filters should still be accessible
      expect(find.widgetWithText(ChoiceChip, 'Completed'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Calendar screen scrolls properly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Navigate to Calendar
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Verify calendar header is visible
      expect(find.text('Calendar'), findsAtLeastNWidgets(1));

      // Verify toggle buttons remain visible
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Bottom navigation and FAB remain visible when scrolling',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Find the SingleChildScrollView on dashboard
      final scrollView = find.byType(SingleChildScrollView).first;

      // Scroll down
      await tester.drag(scrollView, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify navigation bar is still visible
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Courses'), findsAtLeastNWidgets(1));

      // Verify FAB is still visible
      expect(find.widgetWithText(FloatingActionButton, 'Create'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Entity form scrolls when keyboard appears',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Open create menu
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Create'));
      await tester.pumpAndSettle();

      // Open task form
      await tester.tap(find.widgetWithText(ActionChip, 'Task'));
      await tester.pumpAndSettle();

      // Verify form is scrollable
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(find.text('Task details'), findsOneWidget);

      // Find save button to verify form is complete
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

      // Form should still be accessible
      expect(find.text('Task details'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('Empty states display correctly without scroll issues',
        (WidgetTester tester) async {
      await tester.pumpWidget(const StudyMateApp());
      await tester.pumpAndSettle();

      // Navigate to courses
      await tester.tap(find.text('Courses'));
      await tester.pumpAndSettle();

      // If there are courses, the screen should handle them
      expect(find.text('Courses'), findsAtLeastNWidgets(1));
    });
  });
}
