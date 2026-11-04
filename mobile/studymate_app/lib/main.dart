import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/config/firebase_config.dart';
import 'data/services/studymate_api.dart';
import 'features/auth/sign_in_page.dart';
import 'features/auth/study_mate_auth_service.dart';
import 'features/home/study_home_page.dart';
import 'state/study_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseOptions = StudyMateFirebaseConfig.options;
  String? firebaseSetupError;

  if (firebaseOptions != null) {
    try {
      await Firebase.initializeApp(options: firebaseOptions);
    } on FirebaseException catch (error) {
      firebaseSetupError =
          'Firebase n’a pas pu démarrer (${error.code}). Vérifie les options '
          'Firebase fournies au lancement.';
    }
  }

  runApp(
    StudyMateApp(
      firebaseConfigured: firebaseOptions != null && firebaseSetupError == null,
      firebaseSetupError: firebaseSetupError,
      missingFirebaseOptions: StudyMateFirebaseConfig.missingOptions,
    ),
  );
}

class StudyMateApp extends StatefulWidget {
  const StudyMateApp({
    super.key,
    this.firebaseConfigured = false,
    this.missingFirebaseOptions = const [],
    this.firebaseSetupError,
  });

  final bool firebaseConfigured;
  final List<String> missingFirebaseOptions;
  final String? firebaseSetupError;

  @override
  State<StudyMateApp> createState() => _StudyMateAppState();
}

class _StudyMateAppState extends State<StudyMateApp> {
  late final FirebaseAuth? _auth;
  late final StudyController _controller;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _auth = widget.firebaseConfigured ? FirebaseAuth.instance : null;
    final tokenProvider = _auth == null
        ? null
        : () async => await FirebaseAuth.instance.currentUser?.getIdToken();
    final api = StudyMateApi(tokenProvider: tokenProvider);
    _controller = StudyController(api: api);
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6750A4);
    return MaterialApp(
      title: 'StudyMate',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          surface: const Color(0xFFF8F7FC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFECE8F2)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: _AppGate(
        auth: _auth,
        controller: _controller,
        firebaseConfigured: widget.firebaseConfigured,
        firebaseSetupError: widget.firebaseSetupError,
        missingFirebaseOptions: widget.missingFirebaseOptions,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate({
    required this.auth,
    required this.controller,
    required this.firebaseConfigured,
    required this.missingFirebaseOptions,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.firebaseSetupError,
  });

  final FirebaseAuth? auth;
  final StudyController controller;
  final bool firebaseConfigured;
  final String? firebaseSetupError;
  final List<String> missingFirebaseOptions;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    if (auth == null) {
      return _FirebaseConfigurationPage(
        missingOptions: widget.missingFirebaseOptions,
        errorMessage: widget.firebaseSetupError,
      );
    }

    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user != null) return _home(user: user, onConnect: null);
        return SignInPage(auth: auth);
      },
    );
  }

  Widget _home({required User? user, required VoidCallback? onConnect}) {
    final auth = widget.auth;
    return StudyHomePage(
      controller: widget.controller,
      user: user,
      firebaseConfigured: widget.firebaseConfigured,
      firebaseSetupError: widget.firebaseSetupError,
      missingFirebaseOptions: widget.missingFirebaseOptions,
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      onSignOut: auth == null ? null : () => StudyMateAuthService.signOut(auth),
      onConnect: onConnect,
    );
  }
}

class _FirebaseConfigurationPage extends StatelessWidget {
  const _FirebaseConfigurationPage({
    required this.missingOptions,
    this.errorMessage,
  });

  final List<String> missingOptions;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase n’est pas configuré',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ??
                        'Configure Firebase avant de créer un compte ou '
                            'd’accéder aux données StudyMate.',
                    textAlign: TextAlign.center,
                  ),
                  if (missingOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Options manquantes : ${missingOptions.join(', ')}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
