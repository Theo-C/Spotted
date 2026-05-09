import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class Env {
  static String get supabaseUrl => _required('SUPABASE_URL');
  static String get supabaseAnonKey => _required('SUPABASE_ANON_KEY');
  static String get mapboxAccessToken => _required('MAPBOX_ACCESS_TOKEN');
  static String get anthropicApiKey => _required('ANTHROPIC_API_KEY');

  static String _required(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Variable d\'environnement manquante : $key. '
        'Vérifie que .env est présent à la racine et complet (cf. .env.example).',
      );
    }
    return value;
  }
}
