-- =============================================================
-- Spotted — Migration 0010 : seed territoire Aisne (02)
-- =============================================================
-- Ajoute le département de l'Aisne comme 2e territoire curé.
-- Réutilise les 4 catégories existantes (Oiseaux, Mammifères, Reptiles,
-- Chiroptères) — pas de nouvelle catégorie.
--
-- Sélection volontairement compacte (~14 espèces) : on prend un
-- échantillon représentatif de l'écosystème Aisne sans dupliquer la
-- curation Oise dans son intégralité. Les espèces sont toutes déjà
-- présentes dans public.species (héritées des migrations 0004 + 0009),
-- on crée juste les liens species_zones avec la nouvelle zone.
--
-- Différences notables vs Oise (justifications ci-dessous chaque ligne) :
--   - Pic noir : rare en Oise → common en Aisne (forêt de Saint-Gobain)
--   - Cerf élaphe : rare en Oise → common en Aisne (St-Gobain, Retz)
--   - Castor d'Europe : epic en Oise → epic en Aisne (vallée de l'Aisne)
--
-- Pattern : VALUES inline (pas de temp table, cf. leçon 0009).
-- Idempotent via on conflict do nothing.
-- =============================================================

-- -------------------------------------------------------------
-- Statement 1 : créer la zone Aisne (02) si elle n'existe pas
-- -------------------------------------------------------------
insert into public.zones (country_id, name, short_code, type)
select id, 'Aisne', '02', 'department'::zone_type
from public.countries
where iso_code = 'FR'
  and not exists (
    select 1 from public.zones z
    where z.short_code = '02' and z.country_id = countries.id
  );


-- -------------------------------------------------------------
-- Statement 2 : lier les espèces curées à la zone Aisne
-- -------------------------------------------------------------
insert into public.species_zones (species_id, zone_id, rarity)
select sp.id,
       (select id from public.zones where short_code = '02'),
       s.rarity::rarity
from (values
  -- ===== OISEAUX =====
  ('Buteo buteo',           'common'),    -- Buse variable, partout
  ('Falco tinnunculus',     'common'),    -- Faucon crécerelle, plaines
  ('Dendrocopos major',     'common'),    -- Pic épeiche
  ('Ardea cinerea',         'common'),    -- Héron cendré, vallée de l'Aisne
  ('Strix aluco',           'common'),    -- Chouette hulotte, forêts St-Gobain
  ('Dryocopus martius',     'common'),    -- Pic noir : commune en Aisne (St-Gobain) vs rare en Oise
  ('Ciconia nigra',         'legendary'), -- Cigogne noire, en passage migratoire
  -- ===== MAMMIFÈRES =====
  ('Vulpes vulpes',         'common'),    -- Renard roux
  ('Capreolus capreolus',   'common'),    -- Chevreuil
  ('Sus scrofa',            'common'),    -- Sanglier
  ('Cervus elaphus',        'common'),    -- Cerf élaphe : commun en Aisne (St-Gobain, Retz) vs rare en Oise
  ('Castor fiber',          'epic'),      -- Castor d'Europe, vallée de l'Aisne
  -- ===== REPTILES =====
  ('Podarcis muralis',      'common'),    -- Lézard des murailles
  ('Anguis fragilis',       'common'),    -- Orvet fragile
  -- ===== CHIROPTÈRES =====
  ('Pipistrellus pipistrellus', 'common'),-- Pipistrelle commune
  ('Eptesicus serotinus',   'common')     -- Sérotine commune
) as s(scientific_name, rarity)
join public.species sp on sp.scientific_name = s.scientific_name
on conflict (species_id, zone_id) do nothing;


-- =============================================================
-- Vérification post-migration
-- =============================================================
-- Lister les espèces curées par zone :
--   select z.name, c.name as categorie, count(*) as nb
--   from public.species_zones sz
--   join public.zones z on z.id = sz.zone_id
--   join public.species sp on sp.id = sz.species_id
--   join public.categories c on c.id = sp.category_id
--   group by z.name, c.name, c.sort_order
--   order by z.name, c.sort_order;
--
-- Résultat attendu :
--   Aisne | Oiseaux     |  7
--   Aisne | Mammifères  |  5
--   Aisne | Reptiles    |  2
--   Aisne | Chiroptères |  2
--   Aisne total : 16 espèces
--   Oise  | Oiseaux     | 35
--   Oise  | Mammifères  | 15
--   Oise  | Reptiles    |  7
--   Oise  | Chiroptères | 15
--   Oise total : 72 espèces
-- =============================================================
