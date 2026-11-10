import '../../data/models/study_models.dart';

/// Données de démonstration pour tester les nouveaux templates
class DemoData {
  static List<StudyCourse> getSampleCourses() {
    return [
      StudyCourse(
        id: '1',
        title: 'Mathématiques Avancées',
        code: 'MATH301',
        professor: 'Dr. Marie Dupont',
        room: 'A-102',
      ),
      StudyCourse(
        id: '2',
        title: 'Physique Quantique',
        code: 'PHYS401',
        professor: 'Prof. Jean Martin',
        room: 'B-205',
      ),
      StudyCourse(
        id: '3',
        title: 'Programmation Avancée',
        code: 'INFO501',
        professor: 'Dr. Sophie Bernard',
        room: 'C-301',
      ),
      StudyCourse(
        id: '4',
        title: 'Chimie Organique',
        code: 'CHEM202',
        professor: 'Prof. Pierre Dubois',
        room: 'D-104',
      ),
      StudyCourse(
        id: '5',
        title: 'Histoire Moderne',
        code: 'HIST301',
        professor: 'Dr. Claire Rousseau',
        room: 'E-201',
      ),
    ];
  }

  static List<StudyTask> getSampleTasks() {
    return [
      StudyTask(
        id: '1',
        title: 'Terminer le projet de maths',
        description: 'Finir les exercices 12-20 et préparer la présentation',
        priority: 'high',
        isCompleted: false,
        deadline: DateTime.now().add(const Duration(days: 2)),
      ),
      StudyTask(
        id: '2',
        title: 'Réviser le chapitre 5 de physique',
        description: 'Relire les notes et faire les exercices pratiques',
        priority: 'high',
        isCompleted: false,
        deadline: DateTime.now().add(const Duration(days: 1)),
      ),
      StudyTask(
        id: '3',
        title: 'Lire les chapitres 1-3 d\'histoire',
        description: 'Prendre des notes et préparer un résumé',
        priority: 'medium',
        isCompleted: false,
        deadline: DateTime.now().add(const Duration(days: 5)),
      ),
      StudyTask(
        id: '4',
        title: 'TP de chimie - Rapport',
        description: 'Rédiger le rapport du laboratoire de la semaine dernière',
        priority: 'medium',
        isCompleted: true,
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      ),
      StudyTask(
        id: '5',
        title: 'Code review du projet INFO',
        description: 'Réviser le code et préparer les commentaires',
        priority: 'low',
        isCompleted: false,
        deadline: DateTime.now().add(const Duration(days: 7)),
      ),
      StudyTask(
        id: '6',
        title: 'Préparer la présentation finale',
        description: 'Créer les slides et répéter',
        priority: 'high',
        isCompleted: false,
        deadline: DateTime.now().add(const Duration(days: 3)),
      ),
      StudyTask(
        id: '7',
        title: 'Exercices de maths - Série 4',
        description: 'Compléter tous les exercices de la série',
        priority: 'medium',
        isCompleted: true,
        deadline: DateTime.now().subtract(const Duration(days: 2)),
      ),
      StudyTask(
        id: '8',
        title: 'Lire l\'article scientifique',
        description: 'Article sur la mécanique quantique',
        priority: 'low',
        isCompleted: false,
        deadline: DateTime.now().add(const Duration(days: 10)),
      ),
      StudyTask(
        id: '9',
        title: 'Quiz de révision - Physique',
        description: 'Faire le quiz en ligne sur le chapitre 4',
        priority: 'medium',
        isCompleted: true,
        deadline: DateTime.now().subtract(const Duration(days: 3)),
      ),
      StudyTask(
        id: '10',
        title: 'Groupe d\'étude - Maths',
        description: 'Session de groupe pour préparer l\'examen',
        priority: 'high',
        isCompleted: false,
        deadline: DateTime.now().add(const Duration(days: 4)),
      ),
    ];
  }

  static List<StudyNote> getSampleNotes() {
    return [
      StudyNote(
        id: '1',
        title: 'Notes du cours de Mathématiques',
        content: 'Intégrales définies et indéfinies. Formules importantes à retenir pour l\'examen.',
      ),
      StudyNote(
        id: '2',
        title: 'Idées pour le projet INFO',
        content: 'Architecture microservices, API REST, Base de données PostgreSQL. Technologies: Flutter, FastAPI, Docker.',
      ),
      StudyNote(
        id: '3',
        title: 'Résumé - Chimie Organique',
        content: 'Réactions de substitution nucléophile. Mécanismes SN1 et SN2. Différences principales.',
      ),
    ];
  }

  static String getRandomUserName() {
    final names = [
      'Alex',
      'Sophie',
      'Thomas',
      'Emma',
      'Lucas',
      'Léa',
      'Hugo',
      'Chloé',
    ];
    return names[DateTime.now().microsecond % names.length];
  }
}
