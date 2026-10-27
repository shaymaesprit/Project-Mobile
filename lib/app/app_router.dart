import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/supabase_providers.dart';
import '../screens/auth_screen.dart';
import '../screens/study_screens.dart';
import 'supabase_bootstrap.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = SupabaseBootstrap.isConfigured
      ? _AuthRefreshNotifier(Supabase.instance.client)
      : null;
  final router = GoRouter(
    initialLocation: '/app',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (!SupabaseBootstrap.isConfigured) return null;
      final signedIn = Supabase.instance.client.auth.currentSession != null;
      final isAuthRoute = state.matchedLocation == '/auth';
      if (!signedIn && !isAuthRoute) return '/auth';
      if (signedIn && isAuthRoute) return '/app';
      return null;
    },
    routes: [
      GoRoute(
        path: '/app',
        builder: (context, state) => const StudyMateShell(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh?.dispose();
  });
  return router;
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(SupabaseClient client) {
    _subscription = client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
