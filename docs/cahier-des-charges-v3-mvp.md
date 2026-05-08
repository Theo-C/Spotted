# Cahier des charges v3 — MVP

> **Document de travail pour le développement.** Scope volontairement réduit, focus sur 4-6 semaines de dev.
> Pour la vision long terme (multi-comptes, badges, multi-pays, offline-first complet), voir `cahier-des-charges-v2.md`.

---

## 1. Vision (rappel)

App mobile naturaliste **strictement personnelle** (Théo + Axelle) façon "Pokédex" : pour chaque territoire visité, une liste d'espèces remarquables à observer avec rareté, points, et carnet de voyage géolocalisé cumulatif.

**Différenciateurs assumés** : gamification, curation subjective des espèces "intéressantes", rareté contextuelle au territoire, carnet de voyage cumulé sur des années.

---

## 2. Usage réel (validé sur le terrain mental)

```
AVANT la rando  → on consulte l'app au calme, on mémorise 3-4 cibles
PENDANT la rando → on photographie avec l'appareil photo natif (zéro app)
APRÈS la rando   → on importe la photo dans l'app, on coche l'espèce
```

**Conséquences fortes pour le MVP :**
- L'app n'est PAS utilisée en mobilité critique
- Pas besoin de capture caméra in-app
- Pas besoin d'offline-first complexe (sync queue, etc.)
- Le GPS et la date viennent de l'**EXIF de la photo**, pas du téléphone au moment de la saisie
- L'utilisateur peut corriger lieu / date / espèce / observateur si besoin

---

## 3. Périmètre MVP

### ✅ Inclus
- 1 pays : **France**
- 1 territoire curé : **Oise (60)** — ~71 espèces curées
- 4 catégories : **Oiseaux, Mammifères, Reptiles, Chiroptères**
- 1 compte partagé "Théo & Axelle" avec toggle **"qui a observé ?"** sur chaque obs
- Saisie d'observation par **import photo galerie + lecture EXIF + correction manuelle**
- Système **points + niveaux** (formule §5)
- Carte globale des observations (carnet géo)
- Édition / ajout d'espèces (formulaire dynamique)
- Consultation **offline** des fiches du territoire actif (espèces + tuiles Mapbox pré-cachées)

### ❌ Reporté en V2+
- Multi-comptes séparés avec profils
- Badges et niveaux thématiques
- Sous-catégories (filtre par rareté seul au MVP)
- Capture d'observation en mobilité hors ligne (cas d'usage non confirmé)
- Mode "guide de terrain" sépia (mode unifié couleur au MVP)
- Quêtes en cours et streaks de jours
- Profil du binôme et comparatif
- Multi-territoires : **Savoie sera ajoutée juste après MVP** (pas d'ouverture de la France entière, mais quelques territoires curés)
- Multi-pays (Espagne / Tenerife etc.)

---

## 4. Hiérarchie & navigation MVP

```
Accueil
   ↓ tap territoire (Oise)
Liste des catégories (4 tuiles)
   ↓ tap catégorie
Liste des espèces du territoire dans cette catégorie
   • Filtre simple par rareté
   • Tri par nom / rareté / statut observé
   ↓ tap carte d'espèce
Détail espèce + bouton "Nouvelle observation"
```

**Onglets bottom nav (3) :**
- **Explorer** : accueil + drill-down territoire/catégorie/espèce
- **Carnet** : carte globale des observations
- **Profil** : niveau, points, paramètres

**Carte du territoire sur l'accueil** : double zone cliquable
- Tap sur la carte → onglet "Carnet" filtré sur ce territoire
- Tap sur le titre + barre de progression → liste des catégories

---

## 5. Système de points

**Règle** : la 1ʳᵉ observation crédite la majorité des points, les ré-observations gardent une valeur réduite (la flamme reste vive même pour la 50ᵉ chouette).

| Rareté | 1ʳᵉ obs | Re-obs | + photo (1ère) | + photo (re-obs) |
|--------|---------|--------|----------------|------------------|
| Commun | 10 | 2 | 15 | 3 |
| Rare | 30 | 6 | 45 | 9 |
| Épique | 100 | 20 | 150 | 30 |
| Légendaire | 300 | 60 | 450 | 90 |

**Bonus photo +50%** s'applique aux deux types d'obs.
**Bonus photo rétroactif** : si la 1ʳᵉ obs n'avait pas de photo et qu'on en ajoute une plus tard, le bonus est crédité (1 fois par espèce).

### Niveaux

Formule : **niveau N atteint à `N² × 100` points cumulés**

| Niveau | Points cumulés requis |
|--------|----------------------|
| 1 | 0 |
| 2 | 100 |
| 3 | 400 |
| 5 | 1 600 |
| 8 | 6 400 |
| 10 | 9 100 |

Pas de libellé thématique au MVP, juste "Niveau N".

---

## 6. Modèle de données MVP

```
User(id, email, password_hash, pseudo, color_accent)
   -- 2 entrées : Théo et Axelle
   -- Login partagé en pratique, mais distinction sur les obs

Country(id, name, iso_code)
   -- MVP : France uniquement

Zone(id, country_id, name, short_code, type, geojson_url)
   -- MVP : 1 entrée (Oise, type=DEPARTMENT)

Category(id, name, icon, color, sort_order)
   -- 4 entrées : Oiseaux, Mammifères, Reptiles, Chiroptères

Species(id, common_name, scientific_name, category_id,
        description, photo_url, created_by_user_id, created_at)

SpeciesZone(species_id, zone_id, rarity)
   -- rarity ∈ {commun, rare, épique, légendaire}

Observation(id, user_id, species_id, observed_at,
            latitude, longitude, photo_url?, photo_exif_data?,
            is_first_for_user, points_earned, zone_id, created_at)
   -- is_first_for_user calculé à l'insert
   -- points_earned figé au moment du crédit
```

**Pas dans le MVP** : `Badge`, `UserBadge`, `BadgeTier`, `SubCategory`, champs `pending_sync` / `local_id`.

---

## 7. Flow détaillé : saisie d'observation MVP

1. **Tap "+ Nouvelle observation"** (bouton flottant ou depuis fiche d'espèce)
2. **Sélection photo** depuis galerie native (`image_picker`)
3. **Lecture EXIF** automatique : date, GPS lat/lng
4. **Détection du territoire** : reverse-geocoding via Mapbox API ou test GeoJSON local pour vérifier si le point GPS tombe dans une `Zone` curée
5. **Pré-remplissage** :
   - Date observation = date EXIF (modifiable)
   - Lieu = coordonnées EXIF (ajustables sur mini-carte)
   - Territoire = auto-détecté (warning si hors zones curées)
6. **Choix de l'espèce** : liste filtrée par territoire détecté + filtre rareté
7. **Toggle observateur** : "Théo" / "Axelle" (par défaut = user connecté)
8. **Validation** :
   - Si 1ʳᵉ obs : crédit complet + overlay de découverte célébré
   - Sinon : crédit re-obs + simple toast de confirmation
   - Marqueur posé sur le carnet géo

**Cas dégradé** : si pas d'EXIF GPS sur la photo, l'utilisateur doit pointer manuellement sur la carte.

---

## 8. Flow détaillé : ajout d'espèce MVP

Formulaire avec :
- Photo de référence (URL ou upload)
- Nom commun + nom scientifique
- Catégorie (tap pour choisir parmi les 4)
- Présence par territoire avec rareté (au MVP : Oise seulement)
- Description courte (habitat, comportement, signes distinctifs)

**Édition** : possible, sauf retirer un territoire où existe au moins une observation (cadenas).

---

## 9. Stack technique MVP

| Composant | Choix | Notes |
|-----------|-------|-------|
| Frontend | **Flutter** (3.x) | Single codebase iOS/Android |
| State | **Riverpod** 2.x | Plus moderne et testable que Provider |
| Backend | **Supabase** | Auth + Postgres + Storage, free tier OK |
| Cartographie | **Mapbox Maps SDK Flutter** | Style Outdoors par défaut |
| Géocodage | **Mapbox Geocoding API** | Inclus dans le free tier |
| Sélection photo | `image_picker` | Galerie native + caméra fallback |
| Lecture EXIF | `native_exif` ou `exif` | Date + GPS depuis la photo |
| HTTP | `dio` ou `http` | Selon préférence |
| Routing | **go_router** | Navigation déclarative |
| Modèles | **freezed** + **json_serializable** | Types immutables |

**Pas dans le MVP** :
- Drift (SQLite local) — Supabase suffit en online-first
- workmanager (sync queue) — non nécessaire
- Caméra in-app

---

## 10. Authentification MVP

- Email + mot de passe (Supabase Auth)
- Comptes pré-créés en BDD pour Théo et Axelle (pas de signup public)
- Pas de SSO Google/Apple

---

## 11. Estimation effort

**Pour un dev Flutter intermédiaire avec Claude Code en assistance :** ~4-6 semaines de soirées + week-ends.

Décomposition indicative :
- Bootstrap projet + auth Supabase : 3-4 jours
- Modèle de données + seed Oise : 2-3 jours
- Écran liste espèces + détail : 1 semaine
- Flow saisie d'observation (le plus gros) : 1.5-2 semaines
- Carnet géo Mapbox : 4-5 jours
- Polish + animations + tests perso : 1 semaine

---

## 12. Décisions ouvertes restantes

1. **Curation Oise** : à finaliser et fiabiliser avant l'étape "seed BDD"
2. **Photos de référence des espèces** : où les sourcer ? Wikipedia (libre) ou photos perso ?
3. **Premier territoire post-MVP** : Savoie (pour les vacances été 2026)
4. **Hosting Supabase** : free tier d'abord, upgrade quand nécessaire ($25/mois Pro)

---

## Annexes

- `cahier-des-charges-v2.md` — Vision long terme (V2+)
- `curation-oise-v1.md` — Mammifères + Reptiles
- `curation-oise-oiseaux-chiropteres-v1.md` — Oiseaux + Chiroptères
- `wireframes-app-naturaliste-v5.jsx` — Maquettes interactives (référence visuelle)
