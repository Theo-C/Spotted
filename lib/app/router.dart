import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/onboarding_service.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/profile_setup_screen.dart';
import '../features/gamification/presentation/badges_screen.dart';
import '../features/observations/presentation/journal_screen.dart';
import '../features/species/presentation/ai_debug_screen.dart';
import '../features/observations/presentation/new_observation_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/tuto_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/territories/presentation/home_screen.dart';
import '../features/species/presentation/species_detail_screen.dart';
import '../features/species/presentation/species_editor_screen.dart';
import '../features/species/presentation/species_list_screen.dart';
import '../features/territories/presentation/territory_screen.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final onboarding = ref.watch(onboardingServiceProvider);

  return GoRouter(
    initialLocation: '/',
    // Listenable.merge réveille le router à la fois sur changement d'auth et
    // de statut onboarding (notifyListeners appelé par markComplete).
    refreshListenable: Listenable.merge([
      _GoRouterRefreshStream(auth.authStateChanges),
      onboarding,
    ]),
    redirect: (context, state) {
      final isLoggedIn = auth.currentAuthUser != null;
      final loc = state.matchedLocation;
      final isOnLogin = loc == '/login';
      final isOnProfileSetup = loc == '/profile/setup';
      final isOnOnboarding = loc == '/onboarding';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/';

      // Setup profil : nouveau signup Google/MagicLink → trigger DB a créé
      // une ligne public.users avec profile_completed=false + pseudo par
      // défaut (préfixe email). On force l'écran pseudo+couleur avant
      // d'aller plus loin. Silencieux si le AppUser n'a pas encore chargé
      // (asData null) — on laisse passer, le prochain refresh redirigera.
      final appUser = ref.read(currentAppUserProvider).asData?.value;
      if (isLoggedIn &&
          appUser != null &&
          !appUser.profileCompleted &&
          !isOnProfileSetup) {
        return '/profile/setup';
      }
      if (isLoggedIn &&
          appUser != null &&
          appUser.profileCompleted &&
          isOnProfileSetup) {
        return '/';
      }

      // Onboarding perms : tant qu'il n'est pas terminé, on force l'écran
      // dédié. L'état est pré-chargé au boot via OnboardingService.init()
      // dans main.dart — pas de race au 1er build.
      if (isLoggedIn && !onboarding.completed && !isOnOnboarding) {
        return '/onboarding';
      }
      if (isLoggedIn && onboarding.completed && isOnOnboarding) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile/setup',
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/tuto',
        builder: (_, _) => const TutoScreen(),
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
      GoRoute(
        path: '/species/:sid/edit',
        builder: (_, state) => SpeciesEditorScreen(
          speciesId: state.pathParameters['sid']!,
        ),
      ),
      GoRoute(
        path: '/ai-debug',
        builder: (_, _) => const AiDebugScreen(),
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
                routes: [
                  // Sous-route → hérite du shell (bottom nav visible sur
                  // la grille badges). Avant, /badges était top-level et
                  // masquait le footer, désorientation au tap "Voir badges".
                  GoRoute(
                    path: 'badges',
                    builder: (_, _) => const BadgesScreen(),
                  ),
                ],
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
