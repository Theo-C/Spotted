# Spotted — Backlog

État du projet et prochaines actions. Ce fichier est **la source de vérité**
pour "qu'est-ce qui reste à faire" — à jour au fil des sessions.

> Convention : cocher les items faits, les retirer périodiquement pour éviter
> que le fichier devienne un tombeau. L'historique est dans git.

---

## 🔥 En cours / à tester

- [ ] **Tester APK 1.7.1+13 sur téléphone** — Auth Magic Link + séparation user + Espèce du jour + fixes halo/cartes. Checklist Supabase avant test dans [auth-open-signup-setup.md](auth-open-signup-setup.md).

---

## 🎯 Petites features restantes

- [ ] **Plusieurs images par fiche espèce** (~1j) — bucket Supabase + carousel simple. Safe côté storage (150 species × 3 img × 500 KB = 225 MB, largement sous le free tier).
- [ ] **Chiro → papillons** — swap éthique (chiroptères = espèces sensibles). Curation ~15 espèces papillons + retrait des chiros du catalogue Oise. Effort principalement data.

## ⚡ Features d'engagement

- [ ] **Défi hebdomadaire / mensuel** — complément de "Espèce du jour". Ex : "3 mammifères cette semaine", "toutes les mésanges ce mois". À cadrer (durée, sélection, récompense).
- [ ] **Réutiliser `_ObserverDot`** — conservé dans le code pour le futur système d'équipe (affichage pastille couleur d'un coéquipier sur les obs partagées).

## 🏗️ Gros chantiers

- [ ] **Système d'équipe** (V2 essentiel) — création équipe + invitations + RLS SELECT observations étendue pour voir les obs des coéquipiers. Voir commentaire prévoyant la forme SQL dans [migration 0023](../supabase/migrations/0023_observations_select_per_user.sql). Débloque : filtre observer sur la Carte, obs récentes partagées de l'équipe, stats/leaderboard équipe.
- [ ] **Mode hors connexion** — essentiel usage terrain (forêt = pas de réseau). Drift/Isar + file d'attente upload + résolution de conflits. ~1 semaine.
- [ ] **Curation collaborative** — permettre aux users d'ajouter des espèces manquantes de leur département. Modération admin en aval.

## 🏛️ Décisions stratégiques ouvertes

- [x] **Auth grand public** — décidé : Magic Link seul pour l'instant, Google OAuth câblé mais désactivé.
- [ ] **Curation de tous les 96 départements** — chantier éditorial ~1500-2000 espèces à documenter. À trancher (déclencher ? partiel ? crowdsourcé ?).
- [ ] **Abonnement premium (IA illimitée)** — piste évoquée : 5 identifications IA/jour gratuites, illimitée avec abo ~3€/mois. Amortit coût Anthropic + valeur ajoutée sans casser l'UX gratuite. À cadrer si l'app décolle.

## 📦 Setup / infra avant ouverture 10-20 users

- [ ] **Migration Supabase → Pro tier** (~25 $/mo) — nécessaire dès ~1 GB storage (3-6 mois à 20 users actifs) OU 5 GB bandwidth. Débloque aussi les image transformations serveur.
- [ ] **Transformation Supabase pour thumbnails** (`?width=200`) — divise bandwidth × 5 sur les listes. Uniquement Pro tier. À activer après passage Pro.
- [ ] **Rate limit IA** — cap 5-10 identifications/jour/user en free (protège coûts Anthropic). Aligné avec l'idée d'abo premium.
- [ ] **Modération basique** — bouton "signaler" sur les obs + review admin (Diagnostic IA screen ?). Prérequis avant vraie ouverture publique.
- [ ] **Google OAuth activé** (optionnel) — Suivre section 3 de [auth-open-signup-setup.md](auth-open-signup-setup.md). Réactiver le bouton dans `login_screen.dart`.
- [ ] **Signing key release Play Store** — remplacer la clé debug actuelle par une vraie clé de release. ~30 min setup + coffre-fort pour le keystore. Prérequis pour publier sur le Play Store officiellement.
- [ ] **Perf : pagination sur `allObservationsForMapProvider`** — actuellement charge toutes les obs de l'user. OK jusqu'à ~10 000 obs (rare 1 user), mais si équipes activées avec fetch cross-user, prévoir un fetch par viewport carte.

## ❄️ Gelé / mis en pause

- [ ] **iOS distribution** — pas de solution gratuite viable pour side-load durable. Reste sur Android beta. Reprendre quand traction Android validée + budget pour Apple Developer (99 $/an) + Mac.
- [ ] **Système de groupe/équipe** (au sens social) — post-MVP, à distinguer du "système d'équipe" (partage d'obs) ci-dessus.

---

## ✅ Récemment livré (log court)

- **v1.7.1+13** (04/09) — Fix halo au cluster + cartes obs récentes compactées
- **v1.7.0+12** (04/09) — Auth Magic Link + ProfileSetupScreen + séparation user (RLS 0023) + retrait UI cross-user
- **v1.6.4** — Espèce du jour + bonus x2 + notif 8h + marqueur historique sur obs
- **v1.6.x** — Vrai tuto animé + refonte Profil (kebab menu, badges "prochain à débloquer")
- **v1.6.x** — Section "Dernières observations" + territoires en scroll horizontal
- **v1.6.x** — `cached_network_image` + fix cache invalidation badges + trophées 3 accents fiche espèce
- **v1.6.x** — Halo Mapbox (source dédiée) + callout tap-to-open avec chevron animé
