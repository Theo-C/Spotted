-- =============================================================
-- Spotted — Migration 0021 : flag "obs = espèce du jour"
-- =============================================================
-- Colonne booléenne sur observations, set à l'INSERT quand l'espèce
-- observée est celle tirée pour le user pour ce jour-là.
--
-- Permet de marquer visuellement l'obs *a posteriori* (badge "défi du
-- jour" dans le détail, la liste, la Home) sans avoir à re-croiser avec
-- daily_species à chaque affichage.
--
-- Historique : les obs antérieures à cette migration restent à `false`
-- (par défaut) — pas de backfill possible pour les jours où daily_species
-- n'existait pas encore.
-- =============================================================

alter table public.observations
  add column if not exists was_daily_species boolean not null default false;

comment on column public.observations.was_daily_species is
  'True si l''espèce observée était l''espèce du jour de l''user à cette date (figé à l''INSERT).';

-- Vérification :
--   select id, observed_at, was_daily_species from public.observations
--    where user_id = auth.uid()
--    order by observed_at desc limit 10;
