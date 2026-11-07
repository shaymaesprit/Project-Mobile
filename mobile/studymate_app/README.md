# 📚 StudyMate - Application Mobile

Une application de gestion d'études moderne et intuitive avec une interface magnifiquement animée.

## 🎯 Vue d'ensemble du Projet

StudyMate est une application Flutter complète pour les étudiants qui souhaitent organiser leurs cours, tâches, notes et sessions d'étude. L'application dispose d'une interface utilisateur moderne avec deux templates au choix et des animations fluides.

### 🌟 Caractéristiques Principales

- ✅ **Authentification Firebase** - Connexion sécurisée et gestion de compte
- ✅ **Gestion des Cours** - Ajouter, modifier, visualiser vos cours
- ✅ **Gestion des Tâches** - Liste complète avec priorités et statuts
- ✅ **Prise de Notes** - Notes organisées par catégorie
- ✅ **Assistant IA** - Recommandations d'étude personnalisées
- ✅ **API Backend** - Synchronisation des données en temps réel
- ✅ **Two Beautiful UIs** - Choisissez entre Style Moderne ou Créatif
- ✅ **Animations Fluides** - Interface dynamique et engageante
- ✅ **Dark Mode** - Support complet du thème sombre

---

## 📁 Structure du Projet

```
mobile/studymate_app/
├── lib/
│   ├── main.dart                 # Point d'entrée
│   ├── core/
│   │   └── config/
│   │       └── firebase_config.dart
│   ├── data/
│   │   ├── models/
│   │   │   └── study_models.dart
│   │   └── services/
│   │       └── studymate_api.dart
│   ├── features/
│   │   ├── auth/                 # Authentification
│   │   ├── home/                 # Dashboard
│   │   │   ├── modern_dashboard.dart     # Style moderne
│   │   │   ├── creative_dashboard.dart   # Style créatif
│   │   │   ├── dashboard_selector.dart   # Sélecteur de style
│   │   │   ├── demo_data.dart
│   │   │   └── widgets/          # Composants UI
│   │   │       ├── animated_stat_card.dart
│   │   │       ├── animated_course_card.dart
│   │   │       ├── modern_task_card.dart
│   │   │       ├── progress_ring.dart
│   │   │       ├── floating_action_card.dart
│   │   │       ├── streak_card.dart
│   │   │       ├── metric_indicator.dart
│   │   │       ├── neumorphic_card.dart
│   │   │       ├── glassmorphic_card.dart
│   │   │       ├── modern_progress_card.dart
│   │   │       └── widgets.dart  # Export central
│   │   ├── courses/              # Gestion des cours
│   │   ├── profile/              # Profil utilisateur
│   │   ├── study/                # Outils d'étude
│   │   ├── insights/             # Recommandations
│   │   └── notifications/        # Notifications
│   └── state/
│       └── study_controller.dart # Gestion d'état
├── pubspec.yaml                  # Dépendances
├── dart_defines.local.json       # Configuration Firebase
└── README.md                      # Ce fichier
```

---

## 🚀 Installation et Démarrage

### ✅ Prérequis

- **Flutter** 3.3+ ([installer](https://flutter.dev/docs/get-started/install))
- **Dart** 3.0+
- **Android Studio** ou **Xcode** (pour les builds)
- **Git**

### 1️⃣ Cloner le Projet

```bash
git clone https://github.com/yourusername/studymate.git
cd studymate
```

### 2️⃣ Installer les Dépendances

```bash
cd mobile/studymate_app
flutter pub get
```

### 3️⃣ Configurer Firebase

Le fichier `dart_defines.local.json` contient déjà la configuration. Vérifiez :

```json
{
  "STUDYMATE_FIREBASE_API_KEY": "votre_clé",
  "STUDYMATE_FIREBASE_APP_ID": "votre_id",
  "STUDYMATE_FIREBASE_PROJECT_ID": "studymate-8930d",
  "STUDYMATE_API_URL": "http://10.91.105.162:8000/api/v1"
}
```

### 4️⃣ Lancer l'Application

**Sur Android :**
```bash
flutter run --dart-define-from-file=dart_defines.local.json
```

**Sur iOS :**
```bash
flutter run --dart-define-from-file=dart_defines.local.json -d ios
```

**Sur le Web :**
```bash
flutter run -d chrome --dart-define-from-file=dart_defines.local.json
```

---

## 🎨 Deux Templates UI

### Template 1 : Style Moderne 💼

Design professionnel et élégant avec :
- Anneau de progression circulaire
- Cartes avec gradients doux
- Animations subtiles
- Parfait pour un look corporate

```dart
import 'modern_dashboard.dart';

Widget _buildDashboard() {
  return ModernDashboard(
    userName: 'Alex',
    totalTasks: 10,
    completedTasks: 7,
    courses: courses,
    tasks: tasks,
    // ... callbacks
  );
}
```

### Template 2 : Style Créatif 🎨

Design dynamique et coloré avec :
- Hero header animé
- Cartes d'action flottantes
- Gamification avec streak
- Métriques visuelles
- Animations énergiques

```dart
import 'creative_dashboard.dart';

Widget _buildDashboard() {
  return CreativeDashboard(
    userName: 'Alex',
    totalTasks: 10,
    completedTasks: 7,
    courses: courses,
    tasks: tasks,
    // ... callbacks
  );
}
```

### Basculer Entre les Styles

Utilisez le `DashboardSelector` pour permettre à l'utilisateur de choisir :

```dart
import 'dashboard_selector.dart';

return DashboardSelector(
  initialStyle: DashboardStyle.creative,
  userName: 'Alex',
  // ... autres paramètres
);
```

---

## 🎯 Widgets Disponibles

### Widgets Modernes

| Widget | Description | Utilisé dans |
|--------|-------------|--------------|
| `ModernProgressCard` | Anneau de progression avec stats | Modern |
| `ProgressRing` | Anneau circulaire animé | Modern |
| `AnimatedStatCard` | Cartes stat avec shimmer | Modern |
| `ModernTaskCard` | Tâche avec checkbox animée | Les deux |
| `AnimatedCourseCard` | Carte de cours avec gradient | Les deux |

### Widgets Créatifs

| Widget | Description | Utilisé dans |
|--------|-------------|--------------|
| `FloatingActionCard` | Carte d'action pressable | Creative |
| `StreakCard` | Gamification avec série | Creative |
| `MetricIndicator` | Métrique avec tendance | Creative |
| `NeumorphicCard` | Effet neumorphique | Custom |
| `GlassmorphicCard` | Effet glassmorphism | Custom |

---

## 🔌 Intégration dans study_home_page.dart

### Option 1 : Avec Sélecteur (Recommandé)

```dart
import 'dashboard_selector.dart';

class _StudyHomePageState extends State<StudyHomePage> {
  @override
  Widget build(BuildContext context) {
    // ... code existant ...
    
    final pages = [
      _buildDashboard(),  // ← Votre dashboard
      // ... autres pages
    ];
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: DashboardSelector(
        userName: widget.user?.displayName ?? '',
        totalTasks: widget.controller.tasks.length,
        completedTasks: widget.controller.completedTaskCount,
        courses: widget.controller.courses,
        tasks: widget.controller.tasks,
        onCoursesTap: () => _selectPage(1),
        onTasksTap: () => _selectPage(2),
        onAddCourse: _addCourse,
        onAddTask: _addTask,
        onToggleTask: (task, value) => _runAction(
          () => widget.controller.toggleTask(task, value),
        ),
        onNotesTab: () => _selectPage(3),
        onStudyTab: () => _selectPage(4),
        initialStyle: DashboardStyle.creative,
      ),
    );
  }
}
```

### Option 2 : Style Fixe

Remplacez simplement `DashboardSelector` par `ModernDashboard` ou `CreativeDashboard`.

---

## 🎬 Animations Disponibles

Les animations utilisent `flutter_animate` pour des transitions fluides :

```dart
// Fade In
.fadeIn(duration: 400.ms)

// Slide
.slideX(begin: -0.2, end: 0, duration: 400.ms)
.slideY(begin: 0.2, end: 0, duration: 400.ms)

// Scale
.scale(begin: Offset(0.8, 0.8), duration: 400.ms)

// Shimmer
.shimmer(delay: 200.ms, duration: 1000.ms)

// Rotate (infini)
.animate(onPlay: (controller) => controller.repeat())
.rotate(duration: 3000.ms)
```

---

## 🌈 Palette de Couleurs

### Style Moderne
```
Primary:    #6750A4 (Violet)
Secondary:  #8872C5 (Violet clair)
Accent:     #00A86B (Vert)
Surface:    #F8F7FC (Crème)
```

### Style Créatif
```
Header:     #6750A4 → #8872C5 (Gradient)
Courses:    #6750A4 (Violet)
Tasks:      #E91E63 (Rose)
Notes:      #00BCD4 (Cyan)
Study:      #9C27B0 (Mauve)
Streak:     #FF6B6B → #FF8E53 (Gradient)
Success:    #4CAF50 (Vert)
Productivity: #FF9800 (Orange)
```

---

## 📱 Tests et Vérification

### Avant de Committer

```bash
# Analyser le code
flutter analyze

# Formater
dart format .

# Tester
flutter test

# Build APK
flutter build apk --release
```

### Tester les Deux Templates

1. Ouvrez l'app
2. Allez sur le Dashboard (page d'accueil)
3. Cliquez sur le bouton flottant en bas à droite
4. Basculez entre Style Moderne et Style Créatif
5. Vérifiez que tout s'affiche correctement

---

## 🔧 Configuration Backend

Le backend doit être en cours d'exécution sur `http://10.91.105.162:8000`

### Lancer le Backend

```bash
cd backend
.venv\Scripts\Activate.ps1  # Windows
source venv/bin/activate     # macOS/Linux
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### Vérifier la Connexion

```bash
curl http://localhost:8000/api/v1/health
```

Réponse attendue :
```json
{"status":"ok","database":"connected"}
```

---

## 🤖 Assistant IA

L'assistant IA utilise Groq avec le modèle `openai/gpt-oss-120b`.

### Activer l'IA

1. Ouvrir la page Confidentialité
2. Activer "Assistant IA"
3. Utiliser la chat dans les outils d'étude

### Configuration

```env
LLM_PROVIDER=openai
LLM_MODEL=openai/gpt-oss-120b
LLM_BASE_URL=https://api.groq.com/openai/v1
LLM_API_KEY=your_groq_key
```

---

## 📦 Dépendances Principales

```yaml
# UI & Animation
flutter_animate: ^4.5.2
animated_text_kit: ^4.3.0
lottie: ^3.8.2

# Backend & Networking
dio: ^5.11.1
http: ^1.2.0

# Authentication
firebase_auth: ^7.0.1
firebase_core: ^5.1.0
google_sign_in: ^7.2.0

# Storage & Files
firebase_storage: ^14.0.1
image_picker: ^1.2.4

# Utilities
crypto: ^3.0.3
python-dotenv: ^1.0
```

---

## 📚 Structure des Données

### StudyTask
```dart
class StudyTask {
  String id;
  String title;
  String? description;
  String priority;     // 'low', 'medium', 'high'
  bool isCompleted;
  DateTime? dueDate;
}
```

### StudyCourse
```dart
class StudyCourse {
  String id;
  String title;
  String? code;
  String? professor;
  String? room;
  int credits;
}
```

### StudyNote
```dart
class StudyNote {
  String id;
  String title;
  String content;
}
```

---

## 🎓 Cas d'Utilisation

### 1. Organiser vos Cours
```
1. Aller dans "Cours"
2. Cliquer sur "Ajouter un cours"
3. Remplir : Titre, Code, Professeur, Salle
4. Enregistrer
```

### 2. Créer une Tâche
```
1. Aller dans "Tâches"
2. Cliquer sur "Nouvelle tâche"
3. Entrer le titre
4. Définir la priorité
5. Enregistrer
```

### 3. Prendre des Notes
```
1. Aller dans "Notes"
2. Cliquer sur "Nouvelle note"
3. Écrire votre contenu
4. Enregistrer
```

### 4. Utiliser l'IA
```
1. Activer l'assistant IA
2. Aller dans "Outils d'étude"
3. Chat avec l'assistant
4. Recevez des recommandations
```

---

## 🆘 Résolution de Problèmes

### Les animations ne fonctionnent pas
```bash
flutter clean
flutter pub get
flutter run --dart-define-from-file=dart_defines.local.json
```

### Erreur Firebase
- Vérifiez `dart_defines.local.json`
- Vérifiez la clé API Firebase
- Vérifiez la connexion Internet

### Erreur Backend
- Vérifiez que le backend est en cours d'exécution
- Vérifiez l'URL API dans `dart_defines.local.json`
- Vérifiez la base de données PostgreSQL

### L'app est lente
- Désactiver les animations temporairement
- Vérifier la connexion réseau
- Vérifier la mémoire disponible

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📄 Licence

Ce projet est sous licence MIT. Voir `LICENSE` pour plus de détails.

---

## 🎉 Conclusion

Vous êtes prêt à utiliser StudyMate ! Profitez d'une interface moderne et d'animations fluides pour organiser vos études. Choisissez votre style préféré et commencez à être productif ! 🚀

### Commandes Rapides

```bash
# Installation
cd mobile/studymate_app && flutter pub get

# Lancer l'app
flutter run --dart-define-from-file=dart_defines.local.json

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Analyser le code
flutter analyze
```

### Ressources

- [Documentation Flutter](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Firebase Documentation](https://firebase.google.com/docs)
- [flutter_animate](https://pub.dev/packages/flutter_animate)

---

**Créé avec ❤️ pour les étudiants qui veulent réussir** 📚✨

Dernière mise à jour : 2026-11-07
