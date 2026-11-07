# StudyMate - Application Complète de Gestion d'Études

Une application web et mobile complète pour les étudiants, avec backend FastAPI et frontend Flutter.

## 📋 Vue d'ensemble du Projet

StudyMate est une plateforme tout-en-un pour :
- ✅ Gérer vos cours, tâches et notes
- ✅ Suivre votre progression d'étude
- ✅ Recevez des recommandations IA personnalisées
- ✅ Synchroniser les données en temps réel
- ✅ Interface moderne avec deux designs au choix

```
┌─────────────────────────────────────────────┐
│                StudyMate                    │
├─────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────────────┐ │
│  │   Backend    │  │   Application Mobile │ │
│  │  (FastAPI)   │  │     (Flutter)        │ │
│  │  PostgreSQL  │  │  - Style Moderne     │ │
│  │  - API REST  │  │  - Style Créatif     │ │
│  │  - IA (Groq) │  │  - Animations        │ │
│  │  - Firebase  │  │  - Dark Mode         │ │
│  └──────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## 📁 Structure du Projet

```
studymate/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/              # Configuration
│   │   │   ├── config.py
│   │   │   ├── exceptions.py
│   │   │   ├── audit.py
│   │   │   └── logging.py
│   │   ├── api/
│   │   │   ├── router.py
│   │   │   └── routes/
│   │   ├── database/          # Base de données
│   │   │   ├── connection.py
│   │   │   └── session.py
│   │   ├── models/            # ORM Models
│   │   │   ├── user.py
│   │   │   ├── course.py
│   │   │   └── task.py
│   │   ├── schemas/           # Pydantic Schemas
│   │   │   ├── user.py
│   │   │   ├── course.py
│   │   │   └── ai.py
│   │   ├── services/          # Business Logic
│   │   │   ├── user_service.py
│   │   │   ├── ai_service.py
│   │   │   ├── course_service.py
│   │   │   └── task_service.py
│   │   ├── repositories/      # Data Access
│   │   │   ├── user_repository.py
│   │   │   ├── course_repository.py
│   │   │   └── task_repository.py
│   │   └── ml/                # Machine Learning
│   │       ├── m1_learning_profile.py
│   │       ├── m2_behavior.py
│   │       ├── m3_performance.py
│   │       └── m4_recommendations.py
│   ├── alembic/               # Migrations
│   ├── tests/
│   ├── pyproject.toml
│   ├── .env
│   └── requirements.txt
│
├── mobile/studymate_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── features/
│   │   │   ├── home/
│   │   │   │   ├── modern_dashboard.dart
│   │   │   │   ├── creative_dashboard.dart
│   │   │   │   ├── dashboard_selector.dart
│   │   │   │   └── widgets/
│   │   │   ├── auth/
│   │   │   ├── courses/
│   │   │   ├── profile/
│   │   │   └── study/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   └── services/
│   │   └── state/
│   ├── pubspec.yaml
│   ├── dart_defines.local.json
│   └── README.md              # Documentation Flutter
│
├── firebase.json
├── firestore.rules
├── docker-compose.yml
└── README.md                  # Ce fichier
```

---

## 🚀 Installation Rapide

### 1️⃣ Cloner le Projet

```bash
git clone https://github.com/yourusername/studymate.git
cd studymate
```

### 2️⃣ Configuration Backend

#### Via Docker (Recommandé)

```bash
docker-compose up -d
```

Cela va lancer :
- PostgreSQL sur le port 5433
- Redis (si configuré)

#### Manuel

```bash
cd backend

# Créer l'environnement Python
python -m venv .venv

# Activer
# Windows
.venv\Scripts\Activate.ps1
# macOS/Linux
source .venv/bin/activate

# Installer les dépendances
pip install -r requirements.txt

# Configuration
cp .env.example .env
# Éditer .env avec vos valeurs

# Migrations
alembic upgrade head

# Lancer
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3️⃣ Configuration Mobile

```bash
cd mobile/studymate_app

# Installer les dépendances
flutter pub get

# Éditer dart_defines.local.json
# Assurez-vous que l'URL API pointe vers votre backend

# Lancer l'app
flutter run --dart-define-from-file=dart_defines.local.json
```

---

## 🎯 Démarrer l'Application

### Backend

```bash
# Windows
cd backend
.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# macOS/Linux
cd backend
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Le backend sera disponible à : `http://localhost:8000`
API Docs : `http://localhost:8000/docs`

### Application Mobile

```bash
cd mobile/studymate_app
flutter run --dart-define-from-file=dart_defines.local.json
```

### Vérifier la Connexion

```bash
# Vérifier que l'API fonctionne
curl http://localhost:8000/api/v1/health

# Réponse attendue
{"status":"ok","database":"connected"}
```

---

## 🎨 Interface Utilisateur

### Style Moderne 💼

**Caractéristiques :**
- Design professionnel et élégant
- Anneau de progression circulaire
- Gradients doux
- Animations subtiles
- Parfait pour un look corporate

### Style Créatif 🎨

**Caractéristiques :**
- Design dynamique et coloré
- Hero header animé
- Cartes d'action flottantes
- Gamification avec streak
- Animations énergiques
- Parfait pour les étudiants

### Basculer les Styles

Cliquez sur le bouton flottant en bas à droite du dashboard pour passer d'un style à l'autre !

---

## 🔌 Architecture API

### Endpoints Principaux

```
GET    /api/v1/health                    # Santé de l'API
GET    /api/v1/users/me                  # Profil utilisateur
PUT    /api/v1/users/me                  # Mettre à jour le profil
GET    /api/v1/courses                   # Liste des cours
POST   /api/v1/courses                   # Créer un cours
GET    /api/v1/tasks                     # Liste des tâches
POST   /api/v1/tasks                     # Créer une tâche
GET    /api/v1/notes                     # Liste des notes
POST   /api/v1/notes                     # Créer une note
GET    /api/v1/ai/recommendations        # Recommandations IA
POST   /api/v1/ai/chat                   # Chat avec l'IA
```

### Authentification

- **Type :** Firebase JWT
- **Header :** `Authorization: Bearer <token>`

---

## 🤖 Assistant IA

L'assistant IA utilise le modèle `openai/gpt-oss-120b` via Groq API.

### Fonctionnalités

- ✅ Recommandations d'étude personnalisées
- ✅ Chat conversationnel
- ✅ Analyse de profil d'apprentissage
- ✅ Suggestions de planification
- ✅ Mode hors ligne avec fallback règles

### Configuration

```env
LLM_PROVIDER=openai
LLM_MODEL=openai/gpt-oss-120b
LLM_BASE_URL=https://api.groq.com/openai/v1
LLM_API_KEY=your_groq_key
LLM_TIMEOUT_SECONDS=20
```

---

## 📊 Base de Données

### Tables Principales

```
users              # Utilisateurs Firebase
profiles           # Profils étudiants
courses            # Cours
tasks              # Tâches
notes              # Notes
flashcard_decks    # Decks de flashcards
study_sessions     # Sessions d'étude
ai_recommendations # Recommandations IA
ai_insights        # Insights générés par IA
```

### Migrations

```bash
# Créer une nouvelle migration
alembic revision --autogenerate -m "Description"

# Appliquer les migrations
alembic upgrade head

# Revenir en arrière
alembic downgrade -1
```

---

## 🔐 Configuration Firebase

Le projet utilise Firebase pour :
- Authentification
- Stockage de fichiers
- Notifications push

### Configuration Requise

```json
{
  "STUDYMATE_FIREBASE_API_KEY": "your_api_key",
  "STUDYMATE_FIREBASE_APP_ID": "your_app_id",
  "STUDYMATE_FIREBASE_PROJECT_ID": "studymate-8930d",
  "STUDYMATE_FIREBASE_SENDER_ID": "your_sender_id",
  "STUDYMATE_FIREBASE_STORAGE_BUCKET": "your_bucket"
}
```

---

## 🧪 Tests

### Backend

```bash
cd backend
pytest tests/
pytest tests/ -v  # Verbose
pytest tests/test_auth.py  # Test spécifique
```

### Mobile

```bash
cd mobile/studymate_app
flutter test
flutter test test/specific_test.dart
```

---

## 📱 Build et Déploiement

### Build APK (Android)

```bash
cd mobile/studymate_app
flutter build apk --release
# APK généré : build/app/outputs/apk/release/app-release.apk
```

### Build IPA (iOS)

```bash
cd mobile/studymate_app
flutter build ios --release
# Suivez les instructions pour uploader sur App Store
```

### Build Web

```bash
cd mobile/studymate_app
flutter build web --release
# Distribution : build/web/
```

---

## 📚 Documentation Supplémentaire

### Application Mobile
Voir `mobile/studymate_app/README.md` pour :
- Installation détaillée
- Guide des widgets
- Personnalisation UI
- Résolution de problèmes

### Backend
Voir la documentation API :
- `http://localhost:8000/docs` (Swagger UI)
- `http://localhost:8000/redoc` (ReDoc)

---

## 🆘 Résolution de Problèmes

### Les animations ne fonctionnent pas

```bash
flutter clean
flutter pub get
flutter run --dart-define-from-file=dart_defines.local.json
```

### Erreur de base de données

```bash
# Vérifier que PostgreSQL est en cours d'exécution
docker-compose ps

# Vérifier la connexion
psql -U studymate -d studymate
```

### Erreur Firebase

- Vérifiez `dart_defines.local.json`
- Vérifiez la clé API Firebase
- Vérifiez la configuration Firebase Console

### Erreur Backend

```bash
# Vérifier que l'API fonctionne
curl http://localhost:8000/api/v1/health

# Vérifier les logs
# (dans le terminal où vous avez lancé uvicorn)
```

---

## 🤝 Contribution

Les contributions sont les bienvenues !

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📄 Licence

Ce projet est sous licence MIT. Voir `LICENSE` pour plus de détails.

---

## 🎉 Commandes Essentielles

```bash
# Installation Complète
git clone https://github.com/yourusername/studymate.git
cd studymate

# Backend
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1  # ou source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Mobile (dans un autre terminal)
cd mobile/studymate_app
flutter pub get
flutter run --dart-define-from-file=dart_defines.local.json

# Vérifier la santé
curl http://localhost:8000/api/v1/health
```

---

## 📞 Support

Pour obtenir de l'aide :
1. Consultez la documentation des composants
2. Vérifiez les logs d'erreur
3. Ouvrez une issue sur GitHub

---

## 🌟 Fonctionnalités Principales

| Fonctionnalité | Backend | Mobile | Status |
|---|---|---|---|
| Authentification Firebase | ✅ | ✅ | ✅ Production |
| Gestion des Cours | ✅ | ✅ | ✅ Production |
| Gestion des Tâches | ✅ | ✅ | ✅ Production |
| Prise de Notes | ✅ | ✅ | ✅ Production |
| Assistant IA | ✅ | ✅ | ✅ Production |
| Flashcards | ✅ | ⏳ | 🔄 En cours |
| Gamification | ⏳ | ✅ | 🔄 En cours |
| Statistiques | ✅ | ⏳ | 🔄 En cours |

---

**Créé avec ❤️ pour les étudiants qui veulent réussir** 📚✨

Dernière mise à jour : 2026-11-07
Version : 2.0
