-- =============================================================
-- Spotted — Migration 0002 : Row Level Security
-- =============================================================
-- Active RLS sur toutes les tables et définit les policies.
--
-- Logique MVP : "compte partagé Théo & Axelle" → confiance mutuelle.
-- L'app étant strictement personnelle (2 users), les policies sont
-- volontairement permissives entre authentifiés.
--
-- Aucune policy "anon" → sans login, on ne peut RIEN lire/écrire.
-- =============================================================

-- -------------------------------------------------------------
-- Activer RLS sur toutes les tables
-- -------------------------------------------------------------
alter table public.users enable row level security;
alter table public.countries enable row level security;
alter table public.zones enable row level security;
alter table public.categories enable row level security;
alter table public.species enable row level security;
alter table public.species_zones enable row level security;
alter table public.observations enable row level security;

-- -------------------------------------------------------------
-- Tables référentielles (countries, zones, categories)
-- → SELECT pour authenticated. Mutations uniquement via SQL admin
-- (pas de policy INSERT/UPDATE/DELETE = par défaut tout est bloqué
-- pour le rôle authenticated, seul service_role peut écrire).
-- -------------------------------------------------------------
create policy "countries_select" on public.countries
  for select to authenticated using (true);

create policy "zones_select" on public.zones
  for select to authenticated using (true);

create policy "categories_select" on public.categories
  for select to authenticated using (true);

-- -------------------------------------------------------------
-- Species & SpeciesZones
-- → CRUD complet pour authenticated (Théo ou Axelle peut ajouter,
-- éditer ou supprimer une espèce — c'est un compte partagé).
-- -------------------------------------------------------------
create policy "species_select" on public.species
  for select to authenticated using (true);

create policy "species_insert" on public.species
  for insert to authenticated with check (true);

create policy "species_update" on public.species
  for update to authenticated using (true) with check (true);

create policy "species_delete" on public.species
  for delete to authenticated using (true);

create policy "species_zones_select" on public.species_zones
  for select to authenticated using (true);

create policy "species_zones_insert" on public.species_zones
  for insert to authenticated with check (true);

create policy "species_zones_update" on public.species_zones
  for update to authenticated using (true) with check (true);

create policy "species_zones_delete" on public.species_zones
  for delete to authenticated using (true);

-- -------------------------------------------------------------
-- Users (profil)
-- → SELECT pour tous les authentifiés (Théo voit le profil de Axelle
--   et inversement, pour afficher le pseudo/couleur sur les obs).
-- → UPDATE limité à son propre profil (auth.uid() = id).
-- → Pas d'INSERT/DELETE côté app : profils créés en SQL admin
--   ou via trigger sur auth.users (Phase 3).
-- -------------------------------------------------------------
create policy "users_select" on public.users
  for select to authenticated using (true);

create policy "users_update_self" on public.users
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- -------------------------------------------------------------
-- Observations
-- → CRUD complet pour authenticated. Justification :
--   - Théo et Axelle partagent le carnet, chacun peut corriger
--     une obs de l'autre (ex: rectifier une espèce mal identifiée).
--   - Le toggle "qui a observé ?" se manifeste via la colonne
--     user_id (== observateur), pas via le user connecté.
-- → Anti-triche serveur : le trigger trg_observations_is_first
--   recalcule is_first_for_user à chaque INSERT (cf. migration 0001).
-- -------------------------------------------------------------
create policy "observations_select" on public.observations
  for select to authenticated using (true);

create policy "observations_insert" on public.observations
  for insert to authenticated with check (true);

create policy "observations_update" on public.observations
  for update to authenticated using (true) with check (true);

create policy "observations_delete" on public.observations
  for delete to authenticated using (true);

-- =============================================================
-- Vérification : compter les policies par table
-- =============================================================
-- select tablename, count(*) as policies
-- from pg_policies
-- where schemaname = 'public'
-- group by tablename
-- order by tablename;
--
-- Résultat attendu :
--   categories      | 1
--   countries       | 1
--   observations    | 4
--   species         | 4
--   species_zones   | 4
--   users           | 2
--   zones           | 1
-- =============================================================
