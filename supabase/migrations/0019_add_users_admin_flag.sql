-- =============================================================
-- Spotted — Migration 0019 : rôle admin sur public.users
-- =============================================================
-- Ajoute un simple booléen `is_admin` pour gérer qui peut
-- créer / éditer les fiches espèces (catalogue curé).
--
-- Pourquoi pas un vrai RBAC : à 2 users (Théo + Axelle), un
-- booléen suffit largement. On upgradera si besoin.
--
-- Après exécution : lancer `flutter pub run build_runner build`
-- pour régénérer app_user.freezed.dart / .g.dart.
-- =============================================================

alter table public.users
  add column if not exists is_admin boolean not null default false;

comment on column public.users.is_admin is
  'Autorise la création et l''édition des fiches espèces (catalogue).';

-- Seul Théo édite le catalogue au MVP. Axelle reste user standard.
update public.users
   set is_admin = true
 where id = '23c6b2b1-589a-4860-aecd-8f7584bf118d';  -- Théo

-- Vérification :
--   select id, pseudo, is_admin from public.users order by pseudo;
--   → attendu : Axelle=false, Théo=true
