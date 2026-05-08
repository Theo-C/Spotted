# plan.md — Roadmap dev MVP Spotted

> **Plan de bataille du projet.** À cocher au fur et à mesure.
> Chaque phase a une **estimation** et une **definition of done** claire.
> Lire `CLAUDE.md` et `docs/cahier-des-charges-v3-mvp.md` avant d'attaquer.

**Total estimé** : 4-6 semaines de soirées + week-ends pour un dev Flutter intermédiaire avec Claude Code.

---

## 🚀 Démarrage — premier prompt à donner à Claude Code

Une fois Claude Code installé et le repo initialisé, lancer cette commande dans le terminal :

```
claude
```

Puis premier prompt en **Plan Mode** (shift+tab x2 pour activer) :

> Lis `CLAUDE.md` et `docs/cahier-des-charges-v3-mvp.md`, puis lis aussi `plan.md` pour comprendre où on en est. On est en Phase 0. Propose-moi ton plan pour démarrer la Phase 1 (Bootstrap projet). Ne génère rien avant validation.

---

## Phase 0 — Setup environnement (1-2 jours)

Pas de code Flutter ici, juste l'outillage.

### Outils locaux
- [ ] Installer **Flutter SDK** (version stable 3.x) — https://docs.flutter.dev/get-started/install
- [ ] Vérifier `flutter doctor` : tout vert (Android toolchain, IDE, device connecté)
- [ ] Installer **VS Code**
- [ ] Installer extensions VS Code :
  - [ ] Flutter (officielle Dart Code)
  - [ ] Dart
  - [ ] Claude Code
  - [ ] Error Lens (recommandé)
- [ ] Configurer un **émulateur Android** ou connecter un **device physique** (mode développeur activé)
- [ ] Optionnel : Xcode + simulateur iOS si dev Mac

### Comptes externes
- [ ] Créer compte **Supabase** (https://supabase.com) — free tier
- [ ] Créer un nouveau projet Supabase nommé `spotted-prod`
- [ ] Récupérer **URL projet** + **anon key** (Settings → API)
- [ ] Créer compte **Mapbox** (https://mapbox.com) — free tier
- [ ] Générer un **access token** Mapbox (gratuit pour ton volume)
- [ ] Stocker temporairement ces 3 secrets dans un gestionnaire (1Password, KeePass…)

### Repo Git
- [ ] Créer dépôt sur GitHub (privé) : `spotted`
- [ ] Cloner en local
- [ ] Copier dans `docs/` les fichiers : `cahier-des-charges-v2.md`, `cahier-des-charges-v3-mvp.md`, `curation-oise-v1.md`, `curation-oise-oiseaux-chiropteres-v1.md`, `wireframes-app-naturaliste-v5.jsx`
- [ ] Copier `CLAUDE.md` à la racine
- [ ] Copier ce `plan.md` à la racine
- [ ] Premier commit "chore: initial docs"

**✅ DoD Phase 0** : `flutter doctor` est OK, Supabase + Mapbox tokens générés, repo git poussé avec docs.

---

## Phase 1 — Bootstrap projet Flutter (2-3 jours)

### Création
- [ ] `flutter create . --org app.spotted --platforms=android,ios` (depuis `c:\Dev\Flutter\Spotted\`, génère dans le dossier courant)
- [ ] Premier run blanc : `flutter run` → écran compteur affiché

### pubspec.yaml — stack figée
Ajouter dans `dependencies` :
- [ ] `flutter_riverpod: ^2.5.0`
- [ ] `riverpod_annotation: ^2.3.0`
- [ ] `freezed_annotation: ^2.4.0`
- [ ] `json_annotation: ^4.9.0`
- [ ] `go_router: ^14.0.0`
- [ ] `supabase_flutter: ^2.5.0`
- [ ] `mapbox_maps_flutter: ^2.0.0`
- [ ] `image_picker: ^1.1.0`
- [ ] `native_exif: ^0.6.0` (ou `exif`)
- [ ] `dio: ^5.5.0`
- [ ] `google_fonts: ^6.2.0`
- [ ] `flutter_dotenv: ^5.1.0`
- [ ] `intl: ^0.19.0`

Dans `dev_dependencies` :
- [ ] `build_runner: ^2.4.0`
- [ ] `freezed: ^2.5.0`
- [ ] `json_serializable: ^6.8.0`
- [ ] `riverpod_generator: ^2.4.0`
- [ ] `custom_lint: ^0.6.0`
- [ ] `riverpod_lint: ^2.3.0`

- [ ] `flutter pub get`

### Structure de dossiers
Créer la structure feature-first selon `CLAUDE.md` :
- [ ] `lib/app/` (app.dart, router.dart, theme.dart)
- [ ] `lib/core/` (extensions, utils, widgets)
- [ ] `lib/features/auth/` (data, domain, presentation)
- [ ] `lib/features/territories/`
- [ ] `lib/features/species/`
- [ ] `lib/features/observations/`
- [ ] `lib/features/gamification/`
- [ ] `lib/features/profile/`
- [ ] `lib/shared/` (models, providers)

### Configuration secrets
- [ ] Créer `.env` à la racine (et le `.gitignore` !) :
  ```
  SUPABASE_URL=...
  SUPABASE_ANON_KEY=...
  MAPBOX_ACCESS_TOKEN=...
  ```
- [ ] Créer `.env.example` (commit OK, pas de vraies valeurs)
- [ ] Vérifier `.gitignore` contient bien `.env`
- [ ] Charger via `flutter_dotenv` dans `main.dart`

### Thème global
- [ ] Créer `lib/app/theme.dart` avec **tous les design tokens** de `CLAUDE.md` (palette, typo Cormorant Garamond + Karla via `google_fonts`)
- [ ] Définir `ThemeData` Material avec ces tokens
- [ ] Wrapper l'app dans `MaterialApp.router` + `ProviderScope` (Riverpod)

### Routing
- [ ] Créer `lib/app/router.dart` avec `go_router`
- [ ] Routes vides définies : `/login`, `/`, `/territory/:id`, `/category/:id`, `/species/:id`, `/observation/new`, `/profile`, `/map`
- [ ] Bottom nav shell avec 3 onglets (Explorer / Carnet / Profil) — placeholders

### Initialisation Supabase + Mapbox
- [ ] Initialiser `Supabase.initialize()` dans `main.dart`
- [ ] Initialiser `MapboxOptions.setAccessToken()` dans `main.dart`
- [ ] Tester un appel Supabase de check (ex: ping)

**✅ DoD Phase 1** : `flutter run` lance l'app, on voit la bottom nav avec 3 écrans vides au thème vintage. Aucun crash. Code commité.

---

## Phase 2 — Modèle de données + seed Oise (2-3 jours)

### Schéma SQL côté Supabase
Dans le SQL Editor Supabase, créer dans l'ordre :
- [ ] Table `users` (extension de `auth.users`) avec `pseudo`, `color_accent`
- [ ] Table `countries` (id, name, iso_code) + insert France
- [ ] Table `zones` (id, country_id, name, short_code, type, geojson_url) + insert Oise
- [ ] Table `categories` (id, name, icon, color, sort_order) + 4 inserts
- [ ] Table `species` (id, common_name, scientific_name, category_id, description, photo_url, created_by_user_id, created_at)
- [ ] Table `species_zones` (species_id, zone_id, rarity) — composite PK
- [ ] Table `observations` (id, user_id, species_id, observed_at, latitude, longitude, photo_url, photo_exif_data, is_first_for_user, points_earned, zone_id, created_at)
- [ ] Index sur `observations.user_id`, `observations.species_id`
- [ ] Trigger pour calculer `is_first_for_user` à l'insert

### RLS (Row Level Security)
- [ ] Activer RLS sur toutes les tables sensibles
- [ ] Policy : `species`, `species_zones`, `categories`, `zones`, `countries` → SELECT pour tous les authentifiés
- [ ] Policy : `species` INSERT/UPDATE → tout authentifié (l'app est privée)
- [ ] Policy : `observations` → SELECT/INSERT/UPDATE par owner OR partner
- [ ] Test : impossible de lire les obs sans être authentifié

### Modèles Freezed côté Dart
Dans `lib/shared/models/` :
- [ ] `country.dart` (Freezed)
- [ ] `zone.dart`
- [ ] `category.dart`
- [ ] `species.dart`
- [ ] `species_zone.dart`
- [ ] `observation.dart`
- [ ] `app_user.dart`
- [ ] `rarity.dart` (enum + extension fromJson/toJson)
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs`

### Repositories
Pour chaque feature :
- [ ] `SpeciesRepository` (getByZone, getById, create, update)
- [ ] `ObservationRepository` (getMine, create, addPhotoToFirstObs)
- [ ] `ZoneRepository` (getActive, detectFromCoords)
- [ ] `UserRepository` (getCurrent, switchObserver)

### Seed Oise
Script SQL ou Dart oneshot :
- [ ] Insérer les **23 espèces mammifères + reptiles** depuis `curation-oise-v1.md`
- [ ] Insérer les **48 espèces oiseaux + chiroptères** depuis `curation-oise-oiseaux-chiropteres-v1.md`
- [ ] Pour chaque espèce, insérer la liaison `species_zones` avec rareté Oise
- [ ] Vérifier dans Supabase Dashboard : 71 espèces totales

**✅ DoD Phase 2** : Schéma BDD complet, RLS testée, 71 espèces seedées, modèles Freezed compilent, repositories peuvent lire/écrire.

---

## Phase 3 — Auth (1-2 jours)

- [ ] Créer manuellement les 2 comptes Léo + Marine dans Supabase Auth Dashboard
- [ ] Insérer leurs entrées dans `users` avec pseudo + couleur d'accent (vert pour Léo, terracotta pour Marine)
- [ ] Écran `LoginScreen` (selon wireframe v5) — email + mdp
- [ ] `AuthRepository` avec `signIn(email, password)` et `signOut()`
- [ ] `currentUserProvider` (Riverpod) qui expose l'user connecté
- [ ] Garde de route : non auth → redirect `/login`
- [ ] **Toggle observateur** : provider `currentObserverProvider` (peut être différent de `currentUserProvider` puisque compte partagé) — par défaut = user connecté

**✅ DoD Phase 3** : Login fonctionne avec les 2 comptes, on peut switch d'observateur via un toggle visible.

---

## Phase 4 — Navigation & écrans de consultation (1 semaine)

### Bottom nav shell
- [ ] Implémenter la bottom nav (icônes + labels selon wireframe v5)
- [ ] State actif visuel sobre (icône + label gras + petit point)

### Écran d'accueil
- [ ] Header "Carnet naturaliste / Spotted"
- [ ] Bloc niveau (vert foncé, gradient or sur le numéro de niveau)
- [ ] Carte du territoire Oise (SVG stylisé ou tile Mapbox statique)
- [ ] Carte splittée en deux zones cliquables : carte → onglet Carnet, titre/progression → liste catégories
- [ ] Bouton + en haut à droite (placeholder pour ajout)

### Liste des catégories
- [ ] 4 tuiles (oiseaux/mammifères/reptiles/chiroptères)
- [ ] Chaque tuile affiche progression `X/Y` + barre

### Liste des espèces d'une catégorie
- [ ] Header avec icône catégorie + compteur découvertes
- [ ] Filtre par rareté (chips horizontaux : Tous / Commun / Rare / Épique / Légendaire)
- [ ] Filtre par statut (Tout / ✓ Vues / À débusquer)
- [ ] Liste de cartes d'espèces (rareté visuelle, statut observé/non observé)

### Détail d'une espèce
- [ ] Hero avec illustration colorée
- [ ] Nom commun + scientifique
- [ ] Stats (points, bonus photo, statut)
- [ ] Description complète
- [ ] Si observée : historique des obs avec dates / lieux / photo
- [ ] Bouton "Nouvelle observation"
- [ ] Bouton ✏️ pour éditer l'espèce (Phase 8)

**✅ DoD Phase 4** : On peut naviguer Accueil → Liste catégories → Liste espèces → Détail. Tout est lu depuis Supabase. UI fidèle aux wireframes v5.

---

## Phase 5 — Flow saisie d'observation (1.5-2 semaines) ⭐ CŒUR DU MVP

C'est la phase la plus importante. À soigner.

### Sélection de photo
- [ ] Bouton "Nouvelle observation" → permission galerie
- [ ] `image_picker` ouvre la galerie
- [ ] Aperçu de la photo sélectionnée

### Lecture EXIF
- [ ] Extraction des metadata via `native_exif`
- [ ] Récupérer `DateTimeOriginal`, `GPSLatitude`, `GPSLongitude`
- [ ] Si pas de GPS dans l'EXIF → message "Pointe le lieu sur la carte"
- [ ] Si pas de date → message "Précise la date"

### Détection du territoire
- [ ] Reverse-geocoding via Mapbox API → nom du lieu (ex: "Forêt de Compiègne")
- [ ] Détection du territoire curé : test si lat/lng tombe dans un GeoJSON de zone
- [ ] Si hors zones curées → warning "Pas dans un territoire curé"

### Formulaire d'observation
- [ ] Champ date (pré-rempli depuis EXIF, modifiable)
- [ ] Mini-carte avec marqueur (pré-rempli depuis EXIF, repositionnable)
- [ ] Champ lieu textuel (pré-rempli, modifiable)
- [ ] Sélecteur d'espèce → modal qui filtre les espèces du territoire détecté
- [ ] Filtre rareté + recherche dans la modal
- [ ] Toggle observateur (Léo / Marine)

### Validation et crédit
- [ ] Au tap "Valider" :
  - Calcul `is_first_for_user` (query SQL côté serveur)
  - Calcul `points_earned` selon règle (10/30/100/300 ou re-obs 2/6/20/60, +50% si photo)
  - INSERT dans `observations`
- [ ] Si 1ʳᵉ obs : déclencher overlay de découverte (animation, particules, compteur de points)
- [ ] Si re-obs : toast simple "Marqueur ajouté · +X pts"

### Bonus photo rétroactif
- [ ] Sur fiche d'espèce déjà observée sans photo :
- [ ] Bouton "Ajouter une photo · Bonus +X pts"
- [ ] Tap → import photo + UPDATE de la 1ʳᵉ obs + crédit du bonus

**✅ DoD Phase 5** : On peut saisir une observation complète depuis une photo galerie, voir l'overlay de découverte la première fois, et créditer correctement les points (testé manuellement avec 4 raretés différentes).

---

## Phase 6 — Carnet géo Mapbox (4-5 jours)

- [ ] Setup Mapbox dans l'écran Carnet
- [ ] Style "Outdoors" appliqué
- [ ] Charger toutes les `observations` de l'user
- [ ] Afficher un marqueur par observation (couleur = rareté)
- [ ] Animation subtile pour les légendaires (pulse)
- [ ] Tap sur marqueur → bottom sheet avec détail obs (espèce, date, lieu, photo)
- [ ] Filtres en haut (catégorie / rareté / observateur)
- [ ] Stats sous la carte (nb obs, lieux, jours actifs)

**✅ DoD Phase 6** : Carte qui affiche toutes les obs avec leurs marqueurs colorés, tap pour détail.

---

## Phase 7 — Profil & gamification visible (2-3 jours)

- [ ] Écran Profil avec :
  - [ ] Bloc niveau (gradient vert/or, progression vers niveau N+1)
  - [ ] Stats grid (espèces vues, obs totales, photos)
  - [ ] Toggle observateur en gros bouton (switch Léo/Marine)
- [ ] Bouton vers réglages (placeholder)
- [ ] Logout

**Pas de badges au MVP** (reporté V2).

**✅ DoD Phase 7** : Profil complet avec niveau dynamique calculé depuis les points cumulés.

---

## Phase 8 — Édition et ajout d'espèces (3-4 jours)

### Ajout
- [ ] Depuis menu + de l'accueil → "Nouvelle espèce"
- [ ] Formulaire : photo de référence, nom commun, nom scientifique, catégorie, description
- [ ] Sélection rareté pour chaque territoire actif (au MVP : Oise seulement)
- [ ] Validation → INSERT dans `species` + `species_zones`

### Édition
- [ ] Bouton ✏️ depuis fiche d'espèce → ouvre formulaire pré-rempli
- [ ] Bandeau d'avertissement "Tu peux ajouter des territoires mais pas en supprimer un avec obs validées"
- [ ] Cadenas sur les territoires verrouillés
- [ ] Validation → UPDATE espèce + UPDATE/INSERT/DELETE conditionnel des `species_zones`

**✅ DoD Phase 8** : On peut créer une nouvelle espèce et l'éditer, avec respect de la règle cadenas.

---

## Phase 9 — Polish & QA (1 semaine)

### UI/UX
- [ ] Empty states soignés (pas d'observation, pas d'espèce vue, etc.)
- [ ] Loading states partout (skeleton ou spinner)
- [ ] Erreurs gérées avec snackbars/dialogs (pas de crash)
- [ ] Animations clés : transition entre liste→détail, overlay de découverte, mise à jour barre de progression

### Tests métier
- [ ] Tests unitaires sur calcul de points (1ʳᵉ vs re-obs, photo vs pas photo)
- [ ] Test bonus rétroactif (calcul correct)
- [ ] Test calcul niveau (formule N²×100)
- [ ] Test détection territoire depuis lat/lng

### Build et déploiement
- [ ] Configuration `app icon` (logo 🐾 ou empreinte stylisée)
- [ ] Configuration splash screen (vintage, vert forêt + or)
- [ ] Build APK release : `flutter build apk --release`
- [ ] Installation sur les téléphones de Léo et Marine
- [ ] Pour iOS : TestFlight (compte Apple Developer requis, ~99 €/an) OU sideload via Xcode

### Tests réels
- [ ] **Vraie sortie nature** avec une vraie espèce vue
- [ ] Saisie complète depuis photo galerie
- [ ] Vérif crédit points + marqueur sur carnet
- [ ] Saisie d'une 2ᵉ obs de la même espèce → re-obs créditée
- [ ] Test ajout photo rétroactive

**✅ DoD Phase 9** : App installée sur 2 téléphones, première vraie observation enregistrée et validée. **MVP livré.**

---

## 🎉 Post-MVP (à reprioriser après usage réel)

Au moins 1 mois d'utilisation avant de toucher à ces features. Critères de priorisation :
- Qu'est-ce qui m'a manqué le plus en usage réel ?
- Qu'est-ce qui aurait amélioré l'expérience X10 ?

Liste indicative (à challenger) :
- [ ] Curation **Savoie** (avant les vacances été 2026)
- [ ] **Sous-catégories** dans la liste d'espèces (filtres plus fins)
- [ ] **Badges** par catégorie (puis par sous-catégorie)
- [ ] **Multi-comptes séparés** avec profils visibles mutuellement
- [ ] **Mode "guide de terrain" sépia** pour les non-observées
- [ ] **Quêtes en cours** sur l'accueil
- [ ] **Streak de jours actifs** (flamme)
- [ ] **Capture hors ligne** avec sync queue (si vraiment manquant)
- [ ] Multi-pays (Espagne / Tenerife)
- [ ] Catégories additionnelles (amphibiens, poissons, insectes)

---

## 📚 Ressources utiles

- Flutter docs : https://docs.flutter.dev
- Riverpod docs : https://riverpod.dev
- Supabase Flutter : https://supabase.com/docs/reference/dart/initializing
- Mapbox Flutter : https://docs.mapbox.com/flutter/maps/guides/
- Claude Code docs : https://docs.claude.com/en/docs/claude-code/overview
- go_router cookbook : https://pub.dev/packages/go_router

---

## 🪧 Notes de travail

> Espace pour des notes au fil du dev (à éditer librement)

- 
