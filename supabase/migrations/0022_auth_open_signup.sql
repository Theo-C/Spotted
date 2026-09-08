-- =============================================================
-- Spotted — Migration 0022 : ouverture auth public
-- =============================================================
-- Prépare l'auth grand public (Google OAuth + Magic Link email) :
--
-- 1. Ajoute `profile_completed` sur public.users pour distinguer un compte
--    fraîchement créé (pseudo/couleur à choisir) d'un compte prêt à l'usage.
--    Les 2 profils manuels existants (Théo, Axelle) sont flag `true`.
--
-- 2. Ajoute un trigger sur auth.users qui crée automatiquement la ligne
--    public.users correspondante à chaque nouveau signup (peu importe la
--    méthode : Google, Magic Link…). Évite les cas "user auth OK mais
--    pas de profil applicatif" qui cassent les FK observations.user_id.
--
-- Après la migration, l'UI doit :
--   - Rediriger vers /profile/setup si profile_completed = false
--   - Passer profile_completed = true quand le pseudo est saisi
-- =============================================================

-- -------------------------------------------------------------
-- 1. Colonne profile_completed
-- -------------------------------------------------------------
alter table public.users
  add column if not exists profile_completed boolean not null default false;

comment on column public.users.profile_completed is
  'True quand l''user a saisi son pseudo + couleur post-signup.';

-- Les 2 comptes historiques sont déjà setup — on les flag true pour
-- éviter de leur imposer l'écran ProfileSetup au prochain login.
update public.users
   set profile_completed = true
 where pseudo is not null and pseudo <> '';

-- -------------------------------------------------------------
-- 2. Trigger auto-create public.users à chaque signup
-- -------------------------------------------------------------
-- Fonction : appelée par le trigger sur auth.users, insère une ligne
-- correspondante dans public.users. Pseudo par défaut = préfixe email
-- (ex: "theo@..." → "theo") — sera écrasé au ProfileSetupScreen.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  default_pseudo text;
begin
  -- Extrait le préfixe email (avant @) pour un pseudo "provisoire" pas nul.
  default_pseudo := split_part(coalesce(new.email, 'user'), '@', 1);
  -- Cap à 24 chars pour éviter les emails énormes en pseudo.
  if length(default_pseudo) > 24 then
    default_pseudo := substring(default_pseudo from 1 for 24);
  end if;

  insert into public.users (id, pseudo, color_accent, profile_completed)
  values (
    new.id,
    default_pseudo,
    '#1F3D2E',   -- forestGreen par défaut
    false        -- déclenche le ProfileSetupScreen au 1er login
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_auth_user is
  'Auto-crée public.users à chaque signup auth (Google, Magic Link, etc.).';

-- Trigger AFTER INSERT — SECURITY DEFINER dans la fonction contourne
-- la RLS pour l'insert (le nouveau user n'a pas encore de session côté API).
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Vérification :
--   select id, pseudo, profile_completed from public.users order by created_at desc;
