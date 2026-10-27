import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool isConfigured = false;

  static Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty != anonKey.isEmpty) {
      throw StateError(
        'Set both SUPABASE_URL and SUPABASE_ANON_KEY using --dart-define.',
      );
    }
    if (url.isEmpty) return;

    await Supabase.initialize(url: url, anonKey: anonKey);
    isConfigured = true;
  }
}
