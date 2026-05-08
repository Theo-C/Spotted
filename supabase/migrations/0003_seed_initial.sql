-- =============================================================
-- Spotted — Migration 0003 : seed initial (pivot)
-- =============================================================
-- Insère les données pivot du MVP :
--   - 1 pays : France
--   - 1 zone : Oise (département)
--   - 4 catégories : Oiseaux, Mammifères, Reptiles, Chiroptères
--
-- Idempotence partielle via "on conflict" pour pouvoir re-jouer
-- la migration sans dupliquer (utile si tu veux ajuster une
-- couleur/icone et relancer).
-- =============================================================

-- -------------------------------------------------------------
-- Pays
-- -------------------------------------------------------------
insert into public.countries (name, iso_code)
values ('France', 'FR')
on conflict (iso_code) do nothing;

-- -------------------------------------------------------------
-- Zone (Oise — département 60)
-- -------------------------------------------------------------
-- geojson_url laissé null au MVP : la détection territoire
-- (point GPS dans le polygone) sera implémentée Phase 5.
-- On pourra fournir le GeoJSON plus tard sans changer le schéma.
insert into public.zones (country_id, name, short_code, type)
select id, 'Oise', '60', 'department'::zone_type
from public.countries
where iso_code = 'FR'
  and not exists (
    select 1 from public.zones z
    where z.short_code = '60' and z.country_id = countries.id
  );

-- -------------------------------------------------------------
-- Catégories
-- -------------------------------------------------------------
-- icon : identifiant logique (ex: 'birds') — le mapping vers une
--        icône Material/custom se fera côté Dart.
-- color : hex de la palette (cf. lib/app/theme.dart).
insert into public.categories (name, icon, color, sort_order) values
  ('Oiseaux',     'birds',    '#1F3D2E', 0),
  ('Mammifères',  'mammals',  '#B8624A', 1),
  ('Reptiles',    'reptiles', '#C49120', 2),
  ('Chiroptères', 'bats',     '#2D5A42', 3)
on conflict (name) do nothing;

-- =============================================================
-- Vérification
-- =============================================================
-- select
--   (select count(*) from public.countries)  as countries,
--   (select count(*) from public.zones)      as zones,
--   (select count(*) from public.categories) as categories;
--
-- Résultat attendu : 1 / 1 / 4
-- =============================================================
