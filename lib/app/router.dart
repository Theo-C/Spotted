import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/observations/presentation/journal_screen.dart';
import '../features/observations/presentation/new_observation_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/territories/presentation/home_screen.dart';
import '../features/species/presentation/species_detail_screen.dart';
import '../features/species/presentation/species_editor_screen.dart';
import '../features/species/presentation/species_list_screen.dart';
import '../features/territories/presentation/territory_screen.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _GoRouterRefreshStream(auth.authStateChanges),
    redirect: (context, state) {
      final isLoggedIn = auth.currentAuthUser != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/observation/new',
        builder: (_, state) => NewObservationScreen(
          preselectedSpeciesId: state.uri.queryParameters['species'],
        ),
      ),
      GoRoute(
        path: '/species/new',
        builder: (_, _) => const SpeciesEditorScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'territory/:id',
                    builder: (_, state) => TerritoryScreen(
                      zoneId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'category/:cid',
                        builder: (_, state) => SpeciesListScreen(
                          zoneId: state.pathParameters['id']!,
                          categoryId: state.pathParameters['cid']!,
                        ),
                        routes: [
                          GoRoute(
                            path: 'species/:sid',
                            builder: (_, state) => SpeciesDetailScreen(
                              zoneId: state.pathParameters['id']!,
                              speciesId: state.pathParameters['sid']!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (_, _) => const JournalScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Pont entre un Stream et l'API Listenable que GoRouter attend pour
/// re-évaluer ses redirects. Émet un notifyListeners() à chaque event auth.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
