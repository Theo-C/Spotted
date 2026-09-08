import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_providers.dart';
import 'observations_for_map_provider.dart';

/// Combien d'observations récentes on montre dans la section Home
/// "Dernières observations". Assez pour donner de la matière à scroller
/// horizontalement, pas trop pour éviter de tirer trop de photos réseau.
const int _kRecentObsLimit = 10;

/// Les [_kRecentObsLimit] observations les plus récentes de l'utilisateur
/// connecté, triées par date d'observation décroissante.
///
/// Dérive de [allObservationsForMapProvider] — pas de fetch supplémentaire,
/// on trie/coupe la liste déjà en cache. Filtré côté client sur
/// `user_id = soi` en defense-in-depth (la RLS 0023 filtre déjà côté serveur).
final recentObservationsProvider =
    Provider<List<ObservationOnMap>>((ref) {
  final all = ref.watch(allObservationsForMapProvider).asData?.value ??
      const <ObservationOnMap>[];
  final myUserId = ref.watch(currentAuthUserProvider)?.id;
  if (myUserId == null) return const [];
  final mine = all.where((i) => i.obs.userId == myUserId).toList()
    ..sort((a, b) => b.obs.observedAt.compareTo(a.obs.observedAt));
  return mine.take(_kRecentObsLimit).toList();
});
