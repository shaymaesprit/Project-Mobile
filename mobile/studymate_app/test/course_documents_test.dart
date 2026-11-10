import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/data/models/document_models.dart';
import 'package:studymate/data/models/study_models.dart';
import 'package:studymate/data/services/studymate_api.dart';
import 'package:studymate/features/courses/course_documents.dart';
import 'package:studymate/state/study_controller.dart';

class _FakeApi extends StudyMateApi {
  _FakeApi(this.documents) : super(tokenProvider: null);

  final List<CourseDocument> documents;
  bool offline = false;

  @override
  Future<List<CourseDocument>> listCourseDocuments(String courseId) async {
    if (offline) throw const StudyMateApiException('offline', isNetworkError: true);
    return documents;
  }
}

Future<void> _pump(WidgetTester tester, StudyMateApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CourseDocumentsSection(
            key: UniqueKey(),
            controller: StudyController(api: api),
            course: const StudyCourse(id: 'c1', title: 'Biologie'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('parse un PDF de cours et formate sa taille', () {
    final doc = CourseDocument.fromJson({
      'id': 'd1',
      'course_id': 'c1',
      'title': 'Chapitre 1',
      'file_size_bytes': 1572864,
      'page_count': 12,
      'processing_status': 'ready',
      'text_chunks': 9,
      'created_at': '2026-11-10T09:00:00Z',
    });
    expect(doc.sizeLabel, '1,5 Mo');
    expect(doc.pageCount, 12);
    expect(doc.hasText, isTrue);
  });

  testWidgets('liste les PDF du cours et signale les scans', (tester) async {
    await _pump(
      tester,
      _FakeApi([
        CourseDocument(
          id: 'd1',
          title: 'Chapitre 1',
          createdAt: DateTime(2026, 11, 10),
          pageCount: 12,
          sizeBytes: 250000,
          textChunks: 9,
        ),
        CourseDocument(id: 'd2', title: 'TD scanné', createdAt: DateTime(2026, 11, 3), pageCount: 1),
      ]),
    );
    expect(find.text('Documents PDF (2)'), findsOneWidget);
    expect(find.text('Chapitre 1'), findsOneWidget);
    expect(find.text('12 pages · 244 Ko · 10 nov.'), findsOneWidget);
    expect(find.textContaining('scanné (sans texte)'), findsOneWidget);
  });

  testWidgets('sans PDF : invite à en ajouter ; hors ligne : message clair', (tester) async {
    await _pump(tester, _FakeApi(const []));
    expect(find.text('Ajouter'), findsOneWidget);
    expect(find.textContaining('20 Mo max.'), findsOneWidget);

    await _pump(tester, _FakeApi(const [])..offline = true);
    expect(find.textContaining('Hors ligne'), findsOneWidget);
  });
}
