# Spotted — Brief de refonte UI/UX

> Document d'accompagnement des captures d'écran pour la refonte visuelle et ergonomique.
> Il décrit **ce qu'est l'app**, **chaque écran existant**, **les concepts métier** et
> les **contraintes à conserver**. Chaque section peut être annotée à côté d'une capture.
>
> Rédigé le 2026-09-08 — état de l'app post-MVP + itérations gamification.

---

## 1. Ce qu'est Spotted

**Spotted** est un **carnet naturaliste mobile personnel** pour 2 utilisateurs (Théo & Axelle).
Le principe : chaque territoire visité contient une liste d'espèces animales curées ;
on part sur le terrain, on prend des photos avec l'app caméra native, on les importe
dans Spotted qui lit l'EXIF GPS, valide l'observation, et récompense la découverte.

- **Métaphore produit :** "Pokédex naturaliste" — collectionner les espèces, monter en
  niveau, débloquer des badges, poursuivre des quêtes journalières.
- **Ton visuel :** carnet de terrain vintage (crème, vert forêt, terracotta, or) — pas
  d'app d'ornitho institutionnelle, pas de app fitness flashy.
- **Scope :** faune uniquement (oiseaux, mammifères, reptiles, chiroptères), 1 seul
  territoire au MVP (**Oise / 60**), ~72 espèces curées.
- **Compte :** authentification personnelle par utilisateur, mais **carnet partagé en
  lecture** (chacun voit les obs de l'autre sur la carte).
- **Français uniquement**, un seul thème (pas de dark mode).

**Cible :** Théo et Axelle, en sortie nature (forêts de Compiègne / Halatte / Ermenonville,
plaines de l'Oise). Usage typique : rentrer d'une balade, importer 3 photos, valider,
regarder la progression grimper.

---

## 2. Identité visuelle actuelle

### Palette (à conserver comme socle, ajustable)

| Rôle | Nom | Hex |
|------|-----|-----|
| Fond principal | `surfaceBase` | `#F5EDDF` (crème) |
| Cartes | `surfaceCard` | `#FAF6EC` |
| États atténués | `surfaceMuted` | `#F0E8D2` |
| Action / headers | `forestGreen` | `#1F3D2E` (vert forêt) |
| Vert clair | `forestGreenLight` | `#2D5A42` |
| Accent | `terracotta` | `#B8624A` |
| Récompense | `gold` | `#C49120` |
| Or clair | `goldLight` | `#FFD66B` |
| Texte principal | `textPrimary` | `#2A1F15` |
| Texte secondaire | `textSecondary` | `#6B5D4F` |
| Texte discret | `textMuted` | `#A89B86` |

### Couleurs de rareté (sémantique forte, ne pas casser)

| Rareté | Couleur | Hex |
|--------|---------|-----|
| Commun | Gris chaud | `#7A7569` |
| Rare | Bleu profond | `#2D6E8C` |
| Épique | Violet | `#7A3D9A` |
| Légendaire | Or | `#C49120` |

### Typographie

- **Titres :** *Cormorant Garamond* (serif, italique pour les titres principaux).
- **Corps :** *Karla* (sans-serif). Micro-texte en `UPPERCASE`, letter-spacing large,
  bold — sert de "label de section" (`CARNET NATURALISTE`, `CATÉGORIES — 4`, etc.).

### Signature visuelle actuelle

- Cartes arrondies (`borderRadius: 18`) sur fond crème.
- Bordures fines `textMuted @ 30% opacité` — beaucoup plus discrètes que Material.
- Icônes emoji ou Material Outlined selon les cas (à harmoniser dans la refonte ?).
- Aucune animation "flashy" par choix — sobriété assumée dans la CDC.

---

## 3. Architecture de navigation

L'app utilise `go_router` avec un `StatefulShellRoute` à **3 onglets** en bottom bar :

```
┌────────────────────────────────────────┐
│  [Explorer]   [Carnet]   [Profil]      │
│   Icons.explore  Icons.map  Icons.person│
└────────────────────────────────────────┘
```

### Flow principal (drill-down "Explorer")

```
Home (/)
 └── Territoire (/territory/:id)          ← ex: Oise
      └── Catégorie (/category/:cid)       ← ex: Oiseaux
           └── Fiche espèce (/species/:sid)  ← ex: Faucon pèlerin
                └── [CTA "Je l'ai vue !"] → New Observation
```

### Écrans hors-shell (plein écran)

- `/login` — connexion Supabase (magic link + Google)
- `/profile/setup` — pseudo + couleur d'avatar au 1er login
- `/onboarding` — 3 étapes de perms (GPS caméra, notifs)
- `/tuto` — "Comment ça marche" (accessible depuis le kebab profil)
- `/observation/new` — formulaire de saisie d'obs
- `/species/new` et `/species/:sid/edit` — CRUD espèces (admin only)
- `/ai-debug` — diagnostic identification IA (admin only)

### Écrans dans le shell (bottom bar visible)

- `/` — Home
- `/map` — Carnet géo
- `/profile` — Profil
- `/profile/badges` — Grille des badges (sous-route pour garder la bottom bar)

---

## 4. Écrans un par un

Chaque section décrit **l'intention**, les **blocs présents**, et les **frictions
connues ou à interroger** en refonte.

---

### 4.1 Login (`/login`)

**Intention :** entrée dans l'app. Deux méthodes : magic link email + Google Sign-In.

**Blocs :**
- Logo Spotted + baseline
- 2 boutons (Google, Email)
- Champ email + bouton "Envoyer le lien" si magic link choisi
- Message d'état (envoi, erreur, succès)

**Contraintes :** doit rester **très simple** (2 users, pas d'onboarding marketing).

---

### 4.2 Profile setup (`/profile/setup`)

**Intention :** au 1er login, forcer le choix d'un pseudo + d'une couleur d'avatar
(sert de code couleur pour ses obs sur la carte partagée).

**Blocs :**
- Titre "Bienvenue"
- Input pseudo (préfilé avec le début de l'email)
- Sélecteur de couleur (palette limitée)
- Bouton "Terminer"

**Contrainte :** bloque la navigation tant que `profile_completed = false` (redirect
dans `router.dart`).

---

### 4.3 Onboarding perms (`/onboarding`)

**Intention :** 3 étapes montrées **une seule fois** après le profile setup. Explique
les prérequis techniques que Théo/Axelle doivent activer *hors de l'app*.

**Étapes :**
1. **Bienvenue** — pitch produit court.
2. **Activer le GPS dans l'app caméra** — tip visuel (l'app caméra Android/iOS doit
   avoir "Enregistrer la localisation" activé, sinon les EXIF GPS manquent).
3. **Rappels quotidiens** — opt-in notifications OS (optionnel).

**Blocs :** PageView 3 pages + indicateur (dots) + bouton "Suivant" / "Terminer".

**Friction connue :** l'étape 2 est cruciale mais textuelle — un vrai screenshot annoté
de l'app caméra native aiderait, mais compliqué à maintenir cross-device.

---

### 4.4 Home / Explorer (`/`)

**Intention :** cockpit quotidien. C'est l'écran principal, celui qui donne envie de
revenir même sans nouvelle obs à saisir.

**Blocs (de haut en bas) :**
1. **Header** — micro-label `CARNET NATURALISTE` (terracotta, uppercase) + titre
   `Spotted` (Cormorant, forestGreen) + bouton `+` rond (48×48, forestGreen). Le `+`
   ouvre un menu contextuel (nouvelle obs / ajouter espèce si admin).
2. **Progress header** — niveau actuel (ex: "Niveau 4 · 720 pts") + barre de progression
   vers le niveau suivant + flamme de streak (jours consécutifs avec obs).
3. **Quêtes du jour** — carte listant 3 quêtes journalières avec progression + bouton
   "Réclamer" quand complétées.
4. **Espèce du jour** — bannière suggérant une espèce à chercher aujourd'hui (choix
   déterministe basé sur la date).
5. **Dernières observations** — scroll horizontal de vignettes carrées (photo + nom).
   Masqué si aucune obs.
6. **Mes terrains** — section `MES TERRAINS`, liste verticale de cartes territoires
   (au MVP : 1 seule carte, Oise). Chaque carte : nom, code département, progression
   globale (% espèces découvertes).

**Overlays possibles :**
- `LevelUpOverlay` — full-screen quand l'utilisateur passe un niveau.
- `BadgeUnlockOverlay` — full-screen quand un badge se débloque.

**Friction connue :** la Home est **longue** (scroll obligatoire). Question refonte :
condenser en tabs ? Rendre quêtes/espèce du jour collapsables ?

---

### 4.5 Territoire (`/territory/:id`)

**Intention :** vue "carte d'identité" d'un territoire (Oise). Affiche la progression
globale + les 4 catégories animales.

**Blocs :**
1. **Back button** — TextButton avec flèche + label "Retour".
2. **Header territoire** — nom (`Oise`) + code (`60`) en terracotta énorme.
3. **Progress global** — barre + `X / 72 espèces` observées.
4. **Label `CATÉGORIES — 4`**.
5. **Grille 2×2** — 4 cartes catégories (Oiseaux, Mammifères, Reptiles, Chiroptères)
   avec icône + nom + progression `X / N`.

**Friction connue :** au MVP il n'y a qu'un seul territoire, donc l'écran Home →
Territoire ajoute un tap inutile. À interroger : faire de l'Oise l'écran principal
tant qu'il n'y a qu'un territoire ?

---

### 4.6 Liste espèces (`/territory/:id/category/:cid`)

**Intention :** liste filtrable des espèces d'une catégorie dans un territoire.

**Blocs :**
1. Back button.
2. Header catégorie (icône + nom + compteur).
3. **Barre de recherche** — normalise accents/casse (`pelerin` matche `Pèlerin`).
4. **Filtres :**
   - Statut : `Toutes` / `Observées` / `Mystère` (non observées).
   - Rareté : filtre par niveau (Commun → Légendaire) ou toutes.
5. **Tri :** `Rareté ↓` (défaut) / `Mystères d'abord` / `Nom A→Z`.
6. **Liste** — cartes espèces avec vignette photo, nom vernaculaire, nom scientifique,
   badge rareté coloré, checkmark si observée.

**Friction connue :** beaucoup de contrôles au-dessus de la liste (recherche + 2
filtres + tri). À interroger : chip bar horizontale ? Sheet filtres ?

---

### 4.7 Fiche espèce (`/species/:sid`)

**Intention :** page détail d'une espèce, avec CTA principal "Je l'ai vue !".

**Blocs typiques :**
1. Photo hero (plein largeur, possiblement en tap → fullscreen viewer).
2. Nom vernaculaire (Cormorant grand) + nom scientifique (italique).
3. Badge rareté + points potentiels.
4. Description (bio, habitat, comportement).
5. Section "Mes obs" — si déjà observée : miniatures des obs (tap → sheet détail).
6. **CTA `Je l'ai vue !`** — bouton principal en bas, va vers `/observation/new?species=...`.
7. Pour admin : bouton Éditer.

---

### 4.8 Nouvelle observation (`/observation/new`)

**Intention :** flow de saisie d'une obs. C'est **le formulaire critique** de l'app.

**Blocs :**
1. **Photo picker** — bouton "Choisir une photo". Passe par `file_picker` (pas
   `image_picker`) pour préserver l'EXIF GPS sur Android 13+. Aperçu affiché ensuite.
2. **Identification IA** — au moment du pick, l'app envoie la photo à Claude Haiku
   pour proposer une espèce. Suggestion affichée sous forme de card cliquable
   ("On dirait un(e) X — confirmer ?").
3. **Sélecteur d'espèce** — autocomplete (recherchable). Verrouillé si l'obs est
   lancée depuis une fiche espèce (mode preselectedSpeciesId).
4. **Date d'observation** — DateTime picker, prérempli avec EXIF ou now.
5. **Localisation** — coords lat/lng extraites de l'EXIF. Si absent, mini-map Mapbox
   pour placer manuellement le point.
6. **Détection de territoire** — reverse-geocoding Mapbox → nom de commune + région.
   Bloque la validation si région ≠ Oise (message explicite).
7. **Multi-zone selector** — si l'espèce est présente dans plusieurs zones : quelle(s)
   zone(s) crediter (rare).
8. **Bouton `Valider`** — upload photo Supabase Storage + INSERT obs + calcul points
   + dialog découverte si 1ʳᵉ obs de l'espèce.

**Friction connue :** formulaire long et vertical. Beaucoup d'états async (identification
IA, geocoding, upload). Question refonte : layout en étapes (wizard) ou tout en une
page comme aujourd'hui ? Comment rendre le state async lisible ?

---

### 4.9 Carnet géo / Journal (`/map`)

**Intention :** carte Mapbox affichant **toutes les obs** (les siennes + celles du
binôme) sous forme de points colorés par rareté.

**Blocs :**
1. **MapWidget** plein écran (style Outdoors par défaut).
2. **Bouton filtres** (en overlay, collapsé par défaut pour ne pas manger la carte).
   Ouvre une barre horizontale : filtre catégorie + filtre rareté.
3. **Bouton "Layers"** — cycle Outdoors → Satellite Streets → Standard.
4. **Bouton "Ma position"** — recentre sur GPS user.
5. **Clustering** — les points se regroupent en clusters colorés au dézoom, tap →
   zoom sur l'expansion.
6. **Bottom sheet détail** — tap sur un point individuel ouvre une sheet avec la
   photo + espèce + date + auteur.
7. **Callout en bas** — si arrivé depuis une fiche espèce, un callout persiste jusqu'à
   fermeture manuelle.
8. **Overlay de masquage** — cache le fond crème pendant le chargement des tiles pour
   éviter le flicker au boot.

**Friction connue :** les filtres masquent la carte quand ouverts. Le "callout" du bas
peut chevaucher la bottom nav bar. Question refonte : hiérarchiser les contrôles carte,
règles de placement des sheets.

---

### 4.10 Profil (`/profile`)

**Intention :** page perso — stats, badges, réglages.

**Blocs :**
1. **AppBar** avec titre "Profil" (Cormorant) + kebab menu (`⋮`) qui contient :
   - "Comment ça marche" → `/tuto`
   - "Diagnostic IA" → `/ai-debug` (admin only)
   - "Se déconnecter"
2. **Avatar + pseudo + couleur**.
3. **Bloc niveau** — niveau actuel, points cumulés, barre vers next level.
4. **Stats persos** — nombre d'obs, nombre d'espèces uniques, streak actuel, meilleur
   streak.
5. **Toggle "Rappel quotidien"** — switch pour activer/désactiver la notif.
6. **Section Badges** — aperçu 4-6 derniers badges + CTA "Voir tous les badges" →
   `/profile/badges`.

---

### 4.11 Badges (`/profile/badges`)

**Intention :** grille complète des badges (13+), groupés par catégorie.

**Blocs :**
- AppBar "Badges" + back natif.
- Grille responsive : chaque badge en carte carrée, coloré si earned (avec date de
  déblocage) ou grisé si locked (avec progression `X / Y`).
- Catégories : "Premiers pas", "Rareté", "Photo", "Série" (streak).

**Note :** sous-route du profil pour garder la bottom bar visible (choix produit acté
après un bug de désorientation à l'ancien /badges top-level).

---

### 4.12 Tuto (`/tuto`)

**Intention :** aide "Comment ça marche" — accessible en permanence via kebab profil.

**Blocs :** série de sections illustrées (règle de points, streak, quêtes, comment
importer une photo, comment débloquer un badge...).

---

## 5. Concepts métier à connaître pour la refonte

### Rareté (4 niveaux)
`Commun` → `Rare` → `Épique` → `Légendaire`. Détermine la couleur du badge, les
points, et le sentiment de trophée. Doit rester **immédiatement lisible** à l'œil.

### Points

| Rareté | 1ʳᵉ obs | Re-obs | + photo (1ʳᵉ) | + photo (re-obs) |
|--------|---------|--------|---------------|------------------|
| Commun | 10 | 2 | 15 | 3 |
| Rare | 30 | 6 | 45 | 9 |
| Épique | 100 | 20 | 150 | 30 |
| Légendaire | 300 | 60 | 450 | 90 |

### Niveaux
Niveau N atteint à `N² × 100` points cumulés. Overlay full-screen au level-up.

### Streak
Nombre de jours consécutifs avec au moins 1 obs. Représenté par une flamme sur la
Home + stat sur le profil. Se casse à J+2 sans obs.

### Quêtes journalières
3 quêtes générées chaque jour (ex: "observe 1 oiseau", "utilise une photo",
"observe une espèce rare"). Progression visible sur la Home. Bouton "Réclamer" +
récompense points quand complète.

### Espèce du jour
Suggestion déterministe basée sur la date. Bannière sur la Home.

### Badges
Récompenses ponctuelles (13+ badges). Catégories : Premiers pas, Rareté, Photo, Série.
Overlay full-screen au déblocage.

### Découverte
Dialog "minimaliste" au moment de valider une 1ʳᵉ obs d'une espèce (gradient circle
+ texte). La wireframe prévoit une animation "SparkleField" — pas implémentée, à
considérer dans la refonte.

---

## 6. Contraintes et invariants à respecter en refonte

### Doit rester
- **Palette carnet vintage** (crème + vert forêt + terracotta + or). Ajustable sur les
  nuances mais la direction "papier vieilli / naturaliste XIXᵉ" est identitaire.
- **Cormorant Garamond + Karla** (identité typographique forte).
- **Français uniquement**, pas de l10n.
- **Un seul thème** (pas de dark mode).
- **Faune uniquement** — jamais d'icônes végétales (🌿🌳🍀), toujours des icônes
  animales (🐾🐢🦅🦊🦌) ou objets neutres (📔📸🏛).
- **Sobriété > flashy** — animations discrètes, pas de micro-interactions envahissantes
  (cf. CDC).
- **Sémantique des couleurs de rareté** — commun gris / rare bleu / épique violet /
  légendaire or. Ne pas casser.

### Peut évoluer
- Densité d'information sur la Home (aujourd'hui : scroll long).
- Hiérarchie des contrôles sur la carte (filtres, layers, position).
- Layout du formulaire de nouvelle obs (wizard vs page unique).
- Traitement des overlays level-up / badge-unlock (aujourd'hui : full-screen bloquants).
- Style des cartes (radius, ombres, bordures).
- Iconographie (mélange actuel emoji + Material Outlined à harmoniser).

### Frictions remontées à interroger
1. **Home trop longue** — 6 blocs empilés verticalement, obligation de scroller.
2. **Drill-down Home → Territoire redondant** — au MVP il n'y a qu'un seul territoire.
3. **Formulaire nouvelle obs** — beaucoup d'états async, verticalité importante.
4. **Filtres/tri liste espèces** — 3 contrôles au-dessus de la liste.
5. **Carte : callouts et sheets** — chevauchement possible avec la bottom nav.
6. **Onboarding perms étape 2** — texte pur pour expliquer un réglage hors-app.

### Ne pas oublier
- Cible = **2 utilisateurs adultes**, usage principalement **le soir en rentrant** ou
  **sur le terrain en extérieur** (soleil → lisibilité important).
- App **sans pression sociale** — pas de feed public, pas de likes, juste le binôme.
- Gamification = **motivation intrinsèque**, pas manipulatoire.

---

## 7. Suggestion d'ordre pour annoter les captures

Pour un brief efficace, je recommande de capturer et annoter dans cet ordre :

1. Login → Onboarding (parcours 1ᵉʳ lancement)
2. Home (avec quêtes actives + dernières obs)
3. Territoire Oise
4. Liste espèces (une catégorie, avec filtres visibles)
5. Fiche espèce (une observée + une "mystère")
6. Nouvelle observation (les 3 états : vide / photo pickée + IA / prêt à valider)
7. Carte / Carnet géo (avec filtres ouverts + un point tapé)
8. Profil
9. Grille badges
10. Overlays : level-up + badge-unlock + dialog découverte

Pour chaque capture, référencer la section correspondante de ce doc (§4.X) et poser
la question spécifique : *qu'est-ce qui doit changer, qu'est-ce qui doit rester ?*
