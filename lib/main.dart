import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/utils/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  MapboxOptions.setAccessToken(Env.mapboxAccessToken);

  runApp(const ProviderScope(child: SpottedApp()));
}

class SpottedApp extends StatelessWidget {
  const SpottedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Spotted',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      routerConfig: appRouter,
    );
  }
}
