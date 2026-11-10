import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/data/models/study_models.dart';
import 'package:studymate/data/services/studymate_api.dart';
import 'package:studymate/features/home/note_detail_page.dart';
import 'package:studymate/state/study_controller.dart';

void main() {
  const content = 'La mitochondrie produit l’énergie de la cellule.\n\n'
      'Le noyau contient l’ADN et la membrane contrôle les échanges.';

  Future<void> pump(WidgetTester tester, StudyNote note) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteDetailPage(
          controller: StudyController(api: StudyMateApi(tokenProvider: null)),
          note: note,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('affiche tout le contenu de la note', (tester) async {
    await pump(
      tester,
      StudyNote(id: 'n1', title: 'Biologie cellulaire', content: content, updatedAt: DateTime(2026, 11, 10)),
    );
    expect(find.text('Biologie cellulaire'), findsOneWidget);
    expect(find.text(content), findsOneWidget);
    expect(find.text('Modifiée le 10 novembre 2026'), findsOneWidget);
    expect(find.textContaining('17 mots'), findsOneWidget);
  });

  testWidgets('le crayon passe en mode modification', (tester) async {
    await pump(tester, const StudyNote(id: 'n2', title: 'Vide', content: ''));
    expect(find.text('Cette note est vide'), findsOneWidget);

    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier la note'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Vide'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Cette note est vide'), findsOneWidget);
  });
}
