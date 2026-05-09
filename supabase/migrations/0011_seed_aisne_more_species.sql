-- =============================================================
-- Spotted — Migration 0011 : étoffer la curation Aisne
-- =============================================================
-- Complète la migration 0010 qui n'avait curé que 16 espèces sur l'Aisne.
-- Ajoute 36 espèces supplémentaires pour avoir ~52 espèces curées sur le
-- territoire — volume confortable pour le test terrain.
--
-- Toutes ces espèces existent déjà dans public.species (héritées de 0004
-- pour oiseaux + chiroptères, et 0009 pour mammifères + reptiles). On
-- crée juste les liens species_zones avec la zone Aisne.
--
-- Convention rareté : on mirror les raretés Oise (écosystèmes très
-- similaires entre les deux départements). Les seuls cas où on diverge
-- (Pic noir, Cerf élaphe en common Aisne) ont déjà été traités en 0010.
--
-- Pattern : VALUES inline (cf. leçon 0009).
-- Idempotent via on conflict do nothing.
-- =============================================================

insert into public.species_zones (species_id, zone_id, rarity)
select sp.id,
       (select id from public.zones where short_code = '02'),
       s.rarity::rarity
from (values
  -- ===== OISEAUX (+18) =====
  -- Communs
  ('Picus viridis',             'common'),    -- Pic vert
  -- Rares
  ('Accipiter nisus',           'rare'),      -- Épervier d'Europe
  ('Pernis apivorus',           'rare'),      -- Bondrée apivore
  ('Tyto alba',                 'rare'),      -- Chouette effraie
  ('Asio otus',                 'rare'),      -- Hibou moyen-duc
  ('Ardea alba',                'rare'),      -- Grande aigrette
  ('Egretta garzetta',          'rare'),      -- Aigrette garzette
  ('Ciconia ciconia',           'rare'),      -- Cigogne blanche
  ('Dendrocoptes medius',       'rare'),      -- Pic mar (vieilles chênaies de Retz)
  ('Alcedo atthis',             'rare'),      -- Martin-pêcheur d'Europe
  ('Oriolus oriolus',           'rare'),      -- Loriot d'Europe
  ('Luscinia megarhynchos',     'rare'),      -- Rossignol philomèle
  ('Pyrrhula pyrrhula',         'rare'),      -- Bouvreuil pivoine
  -- Épiques
  ('Falco subbuteo',            'epic'),      -- Faucon hobereau
  ('Falco peregrinus',          'epic'),      -- Faucon pèlerin (cathédrale de Laon)
  ('Athene noctua',             'epic'),      -- Chevêche d'Athéna
  ('Upupa epops',               'epic'),      -- Huppe fasciée
  -- Légendaires
  ('Botaurus stellaris',        'legendary'), -- Butor étoilé (marais de la Souche)

  -- ===== MAMMIFÈRES (+8) =====
  -- Communs
  ('Lepus europaeus',           'common'),    -- Lièvre d'Europe
  ('Sciurus vulgaris',          'common'),    -- Écureuil roux
  ('Erinaceus europaeus',       'common'),    -- Hérisson d'Europe
  -- Rares
  ('Martes foina',              'rare'),      -- Fouine
  ('Meles meles',               'rare'),      -- Blaireau européen
  -- Épiques
  ('Martes martes',             'epic'),      -- Martre des pins
  ('Mustela putorius',          'epic'),      -- Putois d'Europe
  -- Légendaires
  ('Lutra lutra',               'legendary'), -- Loutre d'Europe (vallée de l'Aisne)

  -- ===== REPTILES (+4) =====
  -- Rares
  ('Zootoca vivipara',          'rare'),      -- Lézard vivipare
  ('Natrix helvetica',          'rare'),      -- Couleuvre helvétique
  -- Épiques
  ('Vipera berus',              'epic'),      -- Vipère péliade
  ('Coronella austriaca',       'epic'),      -- Coronelle lisse

  -- ===== CHIROPTÈRES (+6) =====
  -- Communs
  ('Pipistrellus kuhlii',       'common'),    -- Pipistrelle de Kuhl
  -- Rares
  ('Nyctalus noctula',          'rare'),      -- Noctule commune
  ('Myotis daubentonii',        'rare'),      -- Murin de Daubenton (chasse au ras de l'Aisne)
  ('Plecotus auritus',          'rare'),      -- Oreillard roux
  -- Épiques
  ('Barbastella barbastellus',  'epic'),      -- Barbastelle d'Europe (St-Gobain, Hirson)
  -- Légendaires
  ('Rhinolophus ferrumequinum', 'legendary')  -- Grand Rhinolophe
) as s(scientific_name, rarity)
join public.species sp on sp.scientific_name = s.scientific_name
on conflict (species_id, zone_id) do nothing;

-- =============================================================
-- Vérification post-migration
-- =============================================================
-- Curation Aisne par catégorie après cette migration :
--   select c.name, count(*) as nb
--   from public.species_zones sz
--   join public.zones z on z.id = sz.zone_id
--   join public.species sp on sp.id = sz.species_id
--   join public.categories c on c.id = sp.category_id
--   where z.short_code = '02'
--   group by c.name, c.sort_order
--   order by c.sort_order;
--
-- Résultat attendu :
--   Oiseaux      | 25  (7 + 18)
--   Mammifères   | 13  (5 + 8)
--   Reptiles     |  6  (2 + 4)
--   Chiroptères  |  8  (2 + 6)
--   Total Aisne : 52 espèces curées.
-- =============================================================
