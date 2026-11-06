import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/data/models/study_models.dart';
import 'package:studymate/data/services/studymate_api.dart';
import 'package:studymate/features/study/study_tools_page.dart';
import 'package:studymate/state/study_controller.dart';

void main() {
  test('parses flashcard progress and evaluation trend summaries', () {
    final progress = StudyFlashcardDeckProgress.fromJson({
      'deck_id': 'deck-1',
      'total_cards': 4,
      'reviewed_cards': 2,
      'mastered_cards': 1,
      'total_reviews': 6,
      'correct_answers': 4,
      'incorrect_answers': 2,
      'accuracy_rate': 66.7,
    });
    final summary = StudyEvaluationSummary.fromJson({
      'graded_count': 1,
      'average_percentage': 80,
      'course_averages': [
        {
          'course_id': 'course-1',
          'average_percentage': 80,
          'evaluation_count': 1,
        },
      ],
      'trend': [
        {
          'evaluation_id': 'evaluation-1',
          'title': 'Quiz',
          'date': '2026-11-01T10:00:00Z',
          'score': 8,
          'max_score': 10,
          'percentage': 80,
        },
      ],
    });

    expect(progress.accuracyRate, closeTo(66.7, 0.01));
    expect(progress.masteredCards, 1);
    expect(summary.averagePercentage, 80);
    expect(summary.trend.single.percentage, 80);
  });

  testWidgets('study tools switch between flashcards and evaluations',
      (tester) async {
    final controller = StudyController(
      api: StudyMateApi(tokenProvider: null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyToolsPage(
            controller: controller,
            onRefresh: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Mes jeux de cartes'), findsOneWidget);
    await tester.tap(find.text('Évaluations'));
    await tester.pumpAndSettle();
    expect(find.text('Mes évaluations'), findsOneWidget);
    expect(find.text('Aucune évaluation'), findsOneWidget);
  });

  testWidgets('flashcard form requires both a question and an answer',
      (tester) async {
    final controller = StudyController(
      api: StudyMateApi(tokenProvider: null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FlashcardFormPage(
          controller: controller,
          deckId: 'deck-1',
        ),
      ),
    );

    await tester.tap(find.text('Créer la carte'));
    await tester.pumpAndSettle();

    expect(find.text('Ce champ est obligatoire.'), findsNWidgets(2));
  });

  testWidgets('evaluation form validates its title', (tester) async {
    final controller = StudyController(
      api: StudyMateApi(tokenProvider: null),
    );
    await tester.pumpWidget(
      MaterialApp(home: EvaluationFormPage(controller: controller)),
    );

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Le nom est obligatoire.'), findsOneWidget);
  });
}
