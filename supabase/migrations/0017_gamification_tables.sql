-- =============================================================
-- Spotted — Migration 0017 : tables gamification (badges + quêtes)
-- =============================================================
-- Pour le système de gamification renforcé (release 1.5.0) :
--   - user_badges : trace quels badges l'user a unlocked + quand
--     (date d'unlock utile pour l'animation "nouveau badge" + l'audit)
--   - user_quest_claims : trace quelles quêtes journalières l'user a
--     claimées (évite de re-créditer le bonus XP plusieurs fois)
--
-- Note de design :
--   - Les badges et quêtes sont DÉFINIS EN CODE Dart (pas en BDD).
--     C'est éditorial et ça évolue avec les sorties. Les tables ici ne
--     stockent que les LIENS user ↔ badge/quête, pas les définitions.
--   - La série (streak) est CALCULÉE à la volée depuis observations.
--     Pas de table dédiée — la source de vérité c'est observed_at.
-- =============================================================

-- -------------------------------------------------------------
-- Table user_badges : qui a unlocked quel badge, quand
-- -------------------------------------------------------------
create table if not exists public.user_badges (
  user_id   uuid not null references auth.users(id) on delete cascade,
  badge_id  text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- Index pour récupérer rapidement les badges d'un user (cas le plus
-- fréquent : afficher la grille Profile).
create index if not exists user_badges_user_id_idx
  on public.user_badges (user_id);

alter table public.user_badges enable row level security;

-- SELECT : chaque user voit ses propres badges (et ceux d'Axelle/Théo
-- — carnet partagé en lecture comme observations).
drop policy if exists "user_badges_select" on public.user_badges;
create policy "user_badges_select" on public.user_badges
  for select to authenticated using (true);

-- INSERT : chaque user n'unlock que ses propres badges.
drop policy if exists "user_badges_insert" on public.user_badges;
create policy "user_badges_insert" on public.user_badges
  for insert to authenticated
  with check (user_id = auth.uid());

-- DELETE : autorisé pour ses propres badges (utile si on veut
-- "re-déclencher" l'animation d'unlock en dev / cas exceptionnels).
drop policy if exists "user_badges_delete" on public.user_badges;
create policy "user_badges_delete" on public.user_badges
  for delete to authenticated using (user_id = auth.uid());


-- -------------------------------------------------------------
-- Table user_quest_claims : quêtes journalières créditées
-- -------------------------------------------------------------
-- claim_date : la date de jour pour laquelle la quête a été claimée
-- (les quêtes daily se réinitialisent à minuit local — on utilise
-- la date côté client pour décider quand une nouvelle quête est dispo).
create table if not exists public.user_quest_claims (
  user_id      uuid not null references auth.users(id) on delete cascade,
  quest_id     text not null,
  claim_date   date not null,
  xp_credited  int  not null default 0,
  created_at   timestamptz not null default now(),
  primary key (user_id, quest_id, claim_date)
);

create index if not exists user_quest_claims_user_date_idx
  on public.user_quest_claims (user_id, claim_date);

alter table public.user_quest_claims enable row level security;

drop policy if exists "user_quest_claims_select" on public.user_quest_claims;
create policy "user_quest_claims_select" on public.user_quest_claims
  for select to authenticated using (true);

drop policy if exists "user_quest_claims_insert" on public.user_quest_claims;
create policy "user_quest_claims_insert" on public.user_quest_claims
  for insert to authenticated
  with check (user_id = auth.uid());

-- Vérification post-migration :
--   select tablename, count(*) as policies
--   from pg_policies
--   where schemaname = 'public' and tablename in ('user_badges', 'user_quest_claims')
--   group by tablename;
--   → user_badges        | 3
--     user_quest_claims  | 2
