# 🚀 GUIDE DE DÉMARRAGE - StudyMate

## ⚡ Start in 5 Minutes

### 1️⃣ Prérequis Installés ?

```bash
✅ Flutter 3.3+    → flutter --version
✅ Dart 3.0+       → dart --version
✅ Python 3.11+    → python --version
✅ Docker (opt)    → docker --version
```

### 2️⃣ Démarrer le Backend

#### Option A : Avec Docker (Facile) 🐳

```bash
docker-compose up -d
# La base de données PostgreSQL démarre automatiquement
```

#### Option B : Manuel

```bash
# Windows
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# macOS/Linux
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

✅ Backend démarre sur `http://localhost:8000`

### 3️⃣ Démarrer l'Application Mobile

```bash
cd mobile/studymate_app
flutter pub get
flutter run --dart-define-from-file=dart_defines.local.json
```

✅ L'app s'ouvre sur votre téléphone/émulateur

### 4️⃣ Tester la Connexion

```bash
# Dans un nouveau terminal
curl http://localhost:8000/api/v1/health

# Réponse attendue
{"status":"ok","database":"connected"}
```

✅ Tout fonctionne !

---

## 📁 Fichiers Importants

```
📦 StudyMate
├── 📄 README.md                    ← Vue d'ensemble du projet
├── 📄 GETTING_STARTED.md          ← Ce fichier
├── docker-compose.yml              ← Lance PostgreSQL
│
├── 📁 backend/
│   ├── 📄 .env                     ← Configuration Backend
│   ├── 📄 pyproject.toml           ← Dépendances Python
│   ├── app/main.py                 ← Point d'entrée
│   └── app/services/ai_service.py  ← Assistant IA
│
└── 📁 mobile/studymate_app/
    ├── 📄 README.md                ← Guide Flutter
    ├── 📄 pubspec.yaml             ← Dépendances Flutter
    ├── 📄 dart_defines.local.json   ← Configuration Firebase
    └── lib/features/home/
        ├── modern_dashboard.dart    ← Template Moderne
        ├── creative_dashboard.dart  ← Template Créatif
        ├── dashboard_selector.dart  ← Sélecteur de style
        └── widgets/                 ← 10+ Widgets animés
```

---

## 🎯 Utilisation Rapide

### 1. Ajouter un Cours
```
Accueil → Mes Cours → + Ajouter un cours
→ Remplir les infos → Enregistrer
```

### 2. Créer une Tâche
```
Accueil → Tâches → + Nouvelle tâche
→ Entrer le titre → Enregistrer
```

### 3. Prendre des Notes
```
Accueil → Notes → + Nouvelle note
→ Écrire le contenu → Enregistrer
```

### 4. Utiliser l'IA
```
Confidentialité → Activer IA
Accueil → Outils d'étude → Chat IA
```

### 5. Changer de Style
```
Accueil → Cliquer sur 🎨 (bas droite)
Modern ↔ Creative
```

---

## 🎨 Deux Designs au Choix

### Style Moderne 💼
- Professionnel et élégant
- Anneau de progression
- Parfait pour le travail

**Commande :**
```dart
initialStyle: DashboardStyle.modern
```

### Style Créatif 🎨
- Dynamique et coloré
- Gamification
- Parfait pour les étudiants

**Commande :**
```dart
initialStyle: DashboardStyle.creative
```

---

## 📱 Test sur Votre Téléphone

### Connecter un Appareil Android

```bash
# Activer le mode développeur
Settings → About → Build number (7x tap)
→ Enable USB Debugging

# Connecter et vérifier
adb devices

# Lancer l'app
flutter run --dart-define-from-file=dart_defines.local.json
```

### Connecter un iPhone

```bash
# Connecter et approuver
# Xcode gère le reste

# Lancer l'app
flutter run --dart-define-from-file=dart_defines.local.json
```

---

## 🔧 Dépannage Rapide

### ❌ L'app ne démarre pas
```bash
flutter clean
flutter pub get
flutter run --dart-define-from-file=dart_defines.local.json
```

### ❌ Erreur Firebase
- Vérifiez `dart_defines.local.json`
- Vérifiez la clé API Firebase

### ❌ Pas de connexion au backend
```bash
# Vérifier que l'API fonctionne
curl http://localhost:8000/api/v1/health
```

### ❌ Les animations ne tournent pas
```bash
# Peut être désactivées dans accessibilité
Settings → Accessibility → Disable Animations (OFF)
```

---

## 🌐 URLs Importantes

```
📱 App                    → Sur votre téléphone
📚 API Health            → http://localhost:8000/api/v1/health
📖 API Docs (Swagger)    → http://localhost:8000/docs
📊 API Docs (ReDoc)      → http://localhost:8000/redoc
🗄️ PostgreSQL            → localhost:5433 (Docker)
🔥 Firebase Console      → https://console.firebase.google.com
```

---

## 📊 Architecture

```
┌─────────────────────────────────────┐
│     Flutter App                     │
│  (Mobile - 2 Designs)               │
└────────────┬────────────────────────┘
             │
             │ HTTP/JSON
             ↓
┌─────────────────────────────────────┐
│     FastAPI Backend                 │
│  (Python - REST API)                │
├─────────────────────────────────────┤
│  Services:                          │
│  - Authentification (Firebase)      │
│  - Gestion des Données              │
│  - Assistant IA (Groq)              │
└────────────┬────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│     PostgreSQL                      │
│     (Base de Données)               │
└─────────────────────────────────────┘
```

---

## 🎓 Fonctionnalités Principales

```
✅ Authentification Firebase
✅ Gestion des Cours
✅ Gestion des Tâches
✅ Prise de Notes
✅ Assistant IA (Groq)
✅ Interface Moderne + Créative
✅ Animations Fluides
✅ Dark Mode
✅ Responsive Design
✅ Synchronisation Temps Réel
```

---

## 📚 Prochaines Étapes

1. ✅ Installer les prérequis
2. ✅ Lancer le backend
3. ✅ Lancer l'app mobile
4. 🔄 Explorer les deux designs
5. 🔄 Ajouter vos premières données
6. 🔄 Utiliser l'assistant IA
7. 🎉 Profiter !

---

## 💡 Conseils

- 📱 Testez d'abord sur émulateur, puis sur appareil réel
- 🎨 Choisissez le design qui vous plaît le plus
- 🤖 Activez l'IA pour des recommandations personnalisées
- 📝 Les données se synchronisent automatiquement
- 🔄 Actualisez avec le bouton en haut (↻)

---

## 🆘 Besoin d'Aide ?

1. **Consultez les README**
   - `README.md` - Vue d'ensemble
   - `mobile/studymate_app/README.md` - Guide Flutter

2. **Vérifiez les logs**
   - Terminal du backend
   - Console de l'app Flutter

3. **Testez la santé**
   ```bash
   curl http://localhost:8000/api/v1/health
   ```

---

## ⚙️ Configuration Avancée

### Changer l'URL de l'API

`mobile/studymate_app/dart_defines.local.json` :
```json
{
  "STUDYMATE_API_URL": "http://votre.serveur.com:8000/api/v1"
}
```

### Activer/Désactiver l'IA

`backend/.env` :
```env
LLM_PROVIDER=openai          # ou 'none' pour désactiver
LLM_API_KEY=votre_clé_groq
```

### Changer le design par défaut

`mobile/studymate_app/lib/features/home/study_home_page.dart` :
```dart
initialStyle: DashboardStyle.creative  // ou modern
```

---

## 🎉 Vous Êtes Prêt !

```
╔═══════════════════════════════════╗
║                                   ║
║   🚀 StudyMate est Prêt ! 🎓     ║
║                                   ║
║   Backend  : ✅ http://localhost  ║
║   App      : ✅ En cours          ║
║   Données  : ✅ Synchronisées     ║
║   IA       : ✅ Prêt              ║
║                                   ║
║   Commencez à Étudier ! 📚✨      ║
║                                   ║
╚═══════════════════════════════════╝
```

---

## 📞 Commandes Rappel

```bash
# Backend
cd backend && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# App Mobile
cd mobile/studymate_app && flutter run --dart-define-from-file=dart_defines.local.json

# Santé
curl http://localhost:8000/api/v1/health

# Nettoyer (si problèmes)
flutter clean && flutter pub get

# Compiler
flutter build apk --release
```

---

**Bonne chance ! Profitez de StudyMate ! 🚀📚✨**

Dernière mise à jour : 2026-11-07
