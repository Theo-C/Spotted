# CLAUDE.md — Spotted

> Constitution du projet pour Claude Code. Lue à chaque session.

## 🎯 Projet

App mobile **personnelle** (2 utilisateurs : Théo & Axelle) façon "Pokédex naturaliste" : pour chaque territoire visité, on consulte les espèces remarquables, on les observe sur le terrain, on importe la photo dans l'app pour valider la découverte et accumuler des points.

**MVP scope** : France, 1 territoire (Oise), 4 catégories animales, ~71 espèces curées, compte partagé, ~4-6 semaines de dev.

**Documents de référence** (à lire avant toute décision structurante) :
- `docs/cahier-des-charges-v3-mvp.md` — **CDC actif** (scope MVP)
- `docs/cahier-des-charges-v2.md` — Vision long terme (V2+, à NE PAS implémenter au MVP)
- `docs/curation-oise-v1.md` — Données mammifères + reptiles
- `docs/curation-oise-oiseaux-chiropteres-v1.md` — Données oiseaux + chiroptères
- `docs/wireframes-app-naturaliste-v5.jsx` — Maquettes interactives (référence visuelle pour les écrans Flutter)

---

## 🏗️ Stack technique

| Composant | Choix | Version cible |
|-----------|-------|---------------|
| Framework | Flutter | 3.x stable |
| Langage | Dart | 3.x |
| State management | **Riverpod** | **3.x** (mis à jour Phase 2.D) |
| Backend | **Supabase** (Auth + Postgres + Storage) | dernière |
| Cartographie | **Mapbox Maps SDK Flutter** (style Outdoors) | 2.x |
| Routing | **go_router** | dernière |
| Modèles | **freezed** + **json_serializable** | **freezed 3.x** (mis à jour Phase 2.D) |
| Sélection photo | `file_picker` | dernière (cf. note ↓) |
| Lecture EXIF | `native_exif` | dernière |
| HTTP | `dio` | dernière |

**À ne PAS introduire au MVP** : Drift / SQLite local, workmanager, caméra in-app, Bloc, Provider, GetX.

**Lints temporairement désactivés** (commentés dans `pubspec.yaml`, à réactiver plus tard) : `custom_lint`, `riverpod_lint` — chaîne `analyzer_plugin 0.12 → analyzer 7.x` pas encore alignée. À retenter quand les linters Riverpod publient une version compatible.

**Breaking changes Freezed 3 à se rappeler** : les classes de modèles s'écrivent désormais `@freezed abstract class Foo with _$Foo { ... }` (mot-clé `abstract` requis depuis 3.0).

**Pourquoi `file_picker` et pas `image_picker`** : sur Android 13+, le nouveau Photo Picker (`MediaStore.ACTION_PICK_IMAGES`) utilisé par `image_picker` 1.x **strippe systématiquement les EXIF GPS** par design — peu importe les permissions accordées. `file_picker` passe par `ACTION_OPEN_DOCUMENT` qui préserve les EXIF. La permission `ACCESS_MEDIA_LOCATION` est aussi déclarée dans `AndroidManifest.xml` (requise depuis Android 10 pour ne pas redacter les coords).

---

## 📐 Architecture

Approche **feature-first** (par domaine), pas layer-first.

```
lib/
├── main.dart
├── app/                          # Configuration globale
│   ├── app.dart                  # MaterialApp + thème
│   ├── router.dart               # go_router
│   └── theme.dart                # Palette couleurs (voir §Design tokens)
├── core/                         # Helpers transverses
│   ├── extensions/
│   ├── utils/
│   └── widgets/                  # Widgets réutilisables (RarityBadge, ProgressBar...)
├── features/
│   ├── auth/                     # Login/logout
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── territories/              # Zones, navigation territoires
│   ├── species/                  # Liste, détail, ajout, édition
│   ├── observations/             # Saisie, carnet géo
│   ├── gamification/             # Calcul points, niveaux
│   └── profile/                  # Profil utilisateur, settings
└── shared/
    ├── models/                   # Modèles Freezed partagés
    └── providers/                # Providers globaux Riverpod
```

Chaque feature contient :
- `data/` : repositories + sources (Supabase, etc.)
- `domain/` : modèles + cas d'usage (logique métier)
- `presentation/` : screens + widgets + providers Riverpod locaux

---

## 🎨 Design tokens

Palette à respecter (look "carnet de naturaliste vintage") :

```dart
// Fond
const surfaceBase = Color(0xFFF5EDDF);     // crème principal
const surfaceCard = Color(0xFFFAF6EC);     // cartes
const surfaceMuted = Color(0xFFF0E8D2);    // états atténués

// Couleurs primaires
const forestGreen = Color(0xFF1F3D2E);     // vert forêt (action, headers)
const forestGreenLight = Color(0xFF2D5A42);
const terracotta = Color(0xFFB8624A);      // accent (numéros département, CTA secondaires)
const gold = Color(0xFFC49120);            // récompense, niveaux
const goldLight = Color(0xFFFFD66B);

// Texte
const textPrimary = Color(0xFF2A1F15);
const textSecondary = Color(0xFF6B5D4F);
const textMuted = Color(0xFFA89B86);

// Raretés
const rarityCommon = Color(0xFF7A7569);
const rarityRare = Color(0xFF2D6E8C);
const rarityEpic = Color(0xFF7A3D9A);
const rarityLegendary = Color(0xFFC49120);
```

**Typographie** :
- Titres : **Cormorant Garamond** (serif, italique pour titres principaux)
- Corps : **Karla** (sans-serif, gras pour micro-texte uppercase)

Importer via `google_fonts` package.

---

## 🧩 Conventions de code

### Nommage
- Fichiers : `snake_case.dart`
- Classes / types : `PascalCase`
- Variables / fonctions : `camelCase`
- Constantes : `lowerCamelCase` (pas `SCREAMING_SNAKE`)
- Providers Riverpod : suffixe `Provider` (ex: `currentUserProvider`)

### Modèles Freezed
Tous les DTO et modèles métier en Freezed, avec sérialisation JSON :

```dart
@freezed
class Species with _$Species {
  const factory Species({
    required String id,
    required String commonName,
    required String scientificName,
    required String categoryId,
    String? description,
    String? photoUrl,
  }) = _Species;

  factory Species.fromJson(Map<String, dynamic> json) =>
      _$SpeciesFromJson(json);
}
```

### Async
Utiliser `AsyncValue` Riverpod pour les états async dans la UI, pas `FutureBuilder`.

### Erreurs
Pas de `throw` brutal. Utiliser `Result<T, E>` ou Either si pertinent. Au minimum, logger les erreurs avec `dart:developer` `log()`.

---

## 🧮 Règles métier critiques

### Système de points (à coder en source unique de vérité)

```dart
const pointsByRarity = {
  Rarity.common: 10,
  Rarity.rare: 30,
  Rarity.epic: 100,
  Rarity.legendary: 300,
};

// Re-observation = 20% du base, arrondi sup
int reobsPoints(Rarity r) => (pointsByRarity[r]! * 0.2).ceil();

// Photo bonus = +50% sur les deux types d'obs
int withPhotoBonus(int basePoints) => (basePoints * 1.5).round();
```

| Rareté | 1ʳᵉ obs | Re-obs | + photo (1ʳᵉ) | + photo (re-obs) |
|--------|---------|--------|---------------|------------------|
| Commun | 10 | 2 | 15 | 3 |
| Rare | 30 | 6 | 45 | 9 |
| Épique | 100 | 20 | 150 | 30 |
| Légendaire | 300 | 60 | 450 | 90 |

### Bonus photo rétroactif
Si l'utilisateur ajoute une photo à une 1ʳᵉ observation déjà validée sans photo, créditer le bonus +50% (1 fois par espèce maximum, jamais sur une re-obs).

### Niveaux
Niveau N atteint à `N² × 100` points cumulés. Pas de descente possible (toujours "+", jamais "-").

### Suppression d'un territoire d'une espèce
Bloquée si **n'importe quel utilisateur** (Théo OU Axelle) a déjà validé une observation sur ce territoire pour cette espèce. Affichage cadenas dans le formulaire d'édition.

### `is_first_for_user`
À calculer au moment de l'INSERT d'une `Observation` :
```sql
SELECT NOT EXISTS (
  SELECT 1 FROM observations 
  WHERE user_id = ? AND species_id = ?
)
```

---

## 🔧 Workflow Claude Code

### Mode opératoire préféré
1. **Plan Mode (shift+tab x2)** avant toute génération substantielle
2. **Une feature à la fois**, pas de gros refactor multi-features
3. **Commits atomiques** avec message descriptif
4. **Tests unitaires** sur la logique métier (calcul points, détection territoire) — pas de tests UI au MVP

### Bonnes habitudes
- Avant d'écrire du code, **lire les fichiers concernés** pour comprendre le contexte existant
- Toujours **citer le fichier source** quand on s'appuie sur une convention
- En cas de doute sur une décision produit, **demander avant d'inventer**
- Ne **jamais introduire** de package non listé dans la stack sans validation

### À éviter
- ❌ Sur-architecture (pas de Clean Architecture stricte, on reste pragmatique)
- ❌ Tests UI Flutter au MVP (lourds à maintenir, faible ROI à 2 users)
- ❌ Internationalisation (l10n) — l'app est en français only
- ❌ Mode sombre / thème clair switch — un seul thème "carnet vintage"
- ❌ Animations excessives — sobriété > flashy

---

## 📦 Commandes utiles

```bash
# Setup initial
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# Génération Freezed après modif
flutter pub run build_runner watch --delete-conflicting-outputs

# Run
flutter run -d <device-id>

# Tests
flutter test

# Analyse statique
flutter analyze
```

---

## 🚧 État actuel du projet

À mettre à jour au fil du dev :

- [x] Bootstrap projet Flutter (Phase 1, 2026-05-08)
- [x] Configuration Supabase (projet, schéma SQL, RLS) (Phase 2.A/2.B)
- [x] Schéma BDD + seed Oise — 50 espèces (35 oiseaux + 15 chiroptères) ; mammifères + reptiles à compléter quand curation v1 récupérée
- [ ] Auth login Supabase (Phase 3)
- [ ] Écran accueil + carte territoire
- [ ] Liste catégories + liste espèces
- [ ] Détail espèce
- [ ] Flow saisie d'observation (import photo + EXIF + validation)
- [ ] Carnet géo Mapbox
- [ ] Profil + niveaux
- [ ] Ajout / édition d'espèces
- [ ] Polish + tests perso
