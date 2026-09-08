# Ouverture Auth — Setup Magic Link (+ Google en option plus tard)

Guide de config à faire côté Supabase Dashboard pour que les nouveaux users
puissent se logger via Magic Link (email passwordless).

> **Note** : Google OAuth est câblé dans le code (`AuthRepository.signInWithGoogle`)
> mais volontairement pas exposé dans l'UI actuelle — on l'a retiré du
> LoginScreen le temps de faire tourner Magic Link seul.
> Pour le réactiver plus tard : suivre la section **3. Google OAuth** ci-dessous
> puis remettre le bouton "Continuer avec Google" dans `login_screen.dart`.

## 1. Migration DB

Jouer les migrations dans l'ordre :

- `0020_daily_species.sql` (si pas déjà fait)
- `0021_observations_was_daily_species.sql` (si pas déjà fait)
- `0022_auth_open_signup.sql` — **critique** : trigger auto-create
  `public.users` à chaque signup + flag `profile_completed`

Vérifier après :

```sql
select id, pseudo, profile_completed from public.users;
```

Théo + Axelle doivent avoir `profile_completed = true`. Les nouveaux signups
apparaîtront avec `false` jusqu'à passage sur ProfileSetupScreen.

## 2. Supabase Dashboard → Auth

### 2.1 URL Configuration

**Authentication → URL Configuration → Redirect URLs** — ajouter :

```
io.spotted.app://auth-callback
```

Sans ça, Supabase rejette les redirections après magic link / OAuth Google.

### 2.2 Email templates (optionnel mais recommandé)

**Authentication → Email Templates → Magic Link** — customiser :

- Sujet : `Ton lien de connexion Spotted`
- Body : remplacer le texte anglais par du français, garder `{{ .ConfirmationURL }}`

Exemple de body :

```html
<h2>Salut !</h2>
<p>Voici ton lien pour te connecter à Spotted :</p>
<p><a href="{{ .ConfirmationURL }}">Ouvrir Spotted</a></p>
<p>Le lien expire dans 1 heure.</p>
```

## 3. Google OAuth (optionnel, à faire plus tard)

### 3.1 Google Cloud Console

1. Aller sur https://console.cloud.google.com/
2. Créer un projet (ex: `spotted-prod`)
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
4. **Application type** : Android
5. **Package name** : `com.example.spotted` (à vérifier dans
   `android/app/build.gradle` — champ `applicationId`)
6. **SHA-1 certificate fingerprint** : générer avec
   ```bash
   cd android && ./gradlew signingReport
   ```
   Prendre le SHA-1 de `Variant: debug` pour le dev. Pour la prod (release
   APK/AAB), utiliser le SHA-1 de la clé de release (ou Play Console →
   Setup → App signing → App signing key certificate).
7. Créer AUSSI un **OAuth client ID de type Web** (utilisé côté Supabase
   backend pour valider les tokens Google) :
   - **Authorized redirect URIs** : ajouter
     `https://<TON_PROJET>.supabase.co/auth/v1/callback`
   - Copier le **Client ID** et le **Client Secret** — nécessaires étape 3.2

### 3.2 Supabase Dashboard → Auth → Providers → Google

1. Enable
2. Coller le **Client ID (Web)** obtenu à l'étape 3.1
3. Coller le **Client Secret**
4. Save

### 3.3 Vérification

Depuis l'app, tap "Continuer avec Google" → doit ouvrir un onglet Chrome
avec le picker de compte Google → sélectionner → retour à l'app → session
créée. Si erreur "redirect_uri_mismatch" → vérifier que la Redirect URI
Web correspond exactement à `https://<projet>.supabase.co/auth/v1/callback`.

## 4. Sanity check final

Tester ces 2 flows Magic Link :

- **Nouveau compte** (email jamais vu) → tap "Recevoir mon lien" → mail
  reçu → tap le bouton "OUVRIR SPOTTED" → app s'ouvre → ProfileSetupScreen
  (pseudo + couleur) → Home
- **Compte historique** (Théo / Axelle par ex.) via Magic Link → skip
  ProfileSetupScreen (déjà `profile_completed = true`) → Home directement

## Debug

- Logs Supabase Auth : Dashboard → Logs → Auth
- Erreur deep link ne s'ouvre pas : vérifier le `<data>` dans
  `AndroidManifest.xml` matche bien `io.spotted.app` + `auth-callback`
- Erreur "signup disabled" : Dashboard → Authentication → Settings →
  activer "Enable email signups" et "Enable phone signups" si nécessaire
