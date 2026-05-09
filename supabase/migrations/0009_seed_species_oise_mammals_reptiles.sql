-- =============================================================
-- Spotted — Migration 0009 : seed espèces Oise (mammifères + reptiles)
-- =============================================================
-- Complète la migration 0004 qui ne couvrait que oiseaux + chiroptères.
-- Ajoute 15 mammifères + 7 reptiles = 22 espèces curées pour Oise (60).
--
-- Curation établie sur la base de l'écologie réelle de l'Oise (climat
-- tempéré océanique, forêts domaniales Compiègne/Halatte/Ermenonville,
-- plaines céréalières, cours d'eau Oise/Aisne/Thérain, bocages).
--
-- Pattern : 2 INSERTs auto-suffisants avec VALUES inline (pas de temp
-- table partagée). On évite la temp table car le SQL Editor Supabase
-- peut exécuter chaque statement dans une session séparée (pgbouncer
-- transaction mode) → la temp table créée par le 1er statement
-- n'existe plus pour le 2e. Bug constaté 2026-05-10 sur cette migration
-- ("relation tmp_species_seed does not exist"). Le pattern temp table
-- de 0004 a marché par chance.
--
-- Idempotence : "on conflict do nothing" sur scientific_name (species)
-- et sur la PK composite (species_zones).
--
-- Note : il y a deux migrations numérotées 0007 sur disque (storage_policies
-- et rls_per_user_observations) — doublon cosmétique sans incidence
-- fonctionnelle. On saute donc directement à 0009.
-- =============================================================

-- -------------------------------------------------------------
-- Statement 1 : INSERT public.species
-- -------------------------------------------------------------
insert into public.species (common_name, scientific_name, category_id, description)
select s.common_name, s.scientific_name, c.id, s.description
from (values
  -- ===== MAMMIFÈRES =====
  -- Communs
  ('Renard roux',          'Vulpes vulpes',         'Très adaptable, présent partout. Visible en bordure de champs au crépuscule, parfois en milieu urbain.',                              'Mammifères'),
  ('Chevreuil européen',   'Capreolus capreolus',   'Le cervidé le plus répandu. Lisières, bocages, forêts. Aboiement caractéristique au rut (juillet-août).',                              'Mammifères'),
  ('Sanglier',             'Sus scrofa',            'Forêts denses, plaines bordées. Plutôt nocturne. Boutis et empreintes très visibles dans les sols meubles.',                            'Mammifères'),
  ('Lièvre d''Europe',     'Lepus europaeus',       'Plaines céréalières, prairies. Plus grand et plus élancé que le lapin, oreilles à pointe noire.',                                       'Mammifères'),
  ('Écureuil roux',        'Sciurus vulgaris',      'Forêts feuillues et mixtes, parcs urbains. Pelage roux à brun foncé, longue queue panachée.',                                           'Mammifères'),
  ('Hérisson d''Europe',   'Erinaceus europaeus',   'Jardins, bocages, lisières. Crépusculaire. En déclin (routes, pesticides). Souvent vu mort sur la chaussée.',                           'Mammifères'),
  -- Rares
  ('Fouine',               'Martes foina',          'Mustélidé proche des habitations (granges, combles). Gorge blanche en bavette. Souvent confondue avec la martre.',                      'Mammifères'),
  ('Belette d''Europe',    'Mustela nivalis',       'Le plus petit carnivore d''Europe. Chasse les campagnols dans bocages et lisières. Très vif, difficile à observer.',                    'Mammifères'),
  ('Blaireau européen',    'Meles meles',           'Nocturne et discret. Terriers profonds en lisière de bois (« blaireautières »). Masque facial noir et blanc.',                          'Mammifères'),
  ('Cerf élaphe',          'Cervus elaphus',        'Grandes forêts domaniales (Compiègne, Halatte). Brame spectaculaire en septembre-octobre. Mâle imposant, ramure complexe.',             'Mammifères'),
  -- Épiques
  ('Martre des pins',      'Martes martes',         'Mustélidé strictement forestier (vieilles futaies). Gorge crème, plus grande que la fouine. Très discrète.',                            'Mammifères'),
  ('Castor d''Europe',     'Castor fiber',          'En recolonisation lente le long de l''Oise et de l''Aisne. Indices : arbres rongés en sablier, huttes, barrages.',                       'Mammifères'),
  ('Putois d''Europe',     'Mustela putorius',      'Mustélidé masqué (face en bandits noir et blanc). Zones humides, bocages. En fort déclin national.',                                   'Mammifères'),
  -- Légendaires
  ('Chat forestier',       'Felis silvestris',      'En limite d''aire occidentale, recolonisation possible depuis l''Est. Gris tigré, queue épaisse à anneaux noirs nets.',                 'Mammifères'),
  ('Loutre d''Europe',     'Lutra lutra',           'Disparue de Picardie au XXe siècle, retour signalé sur quelques cours d''eau. Indices (épreintes) plutôt que vue directe.',              'Mammifères'),

  -- ===== REPTILES =====
  -- Communs
  ('Lézard des murailles', 'Podarcis muralis',      'Le reptile le plus visible. Murs ensoleillés, jardins, ruines. Vif, souvent en pleine lumière à mi-journée.',                           'Reptiles'),
  ('Orvet fragile',        'Anguis fragilis',       'Lézard apode souvent confondu avec un serpent. Sous pierres, bois, compost. Brun cuivré brillant.',                                     'Reptiles'),
  -- Rares
  ('Lézard vivipare',      'Zootoca vivipara',      'Milieux humides frais (tourbières, prairies humides). Plus discret que le lézard des murailles, brun-vert.',                            'Reptiles'),
  ('Couleuvre helvétique', 'Natrix helvetica',      'Zones humides, étangs, fossés. Collier jaune et noir derrière la tête. Inoffensive, fuit à l''approche.',                                'Reptiles'),
  -- Épiques
  ('Vipère péliade',       'Vipera berus',          'Landes humides forestières, lisières exposées. Zigzag dorsal noir caractéristique. Seule vipère de l''Oise.',                            'Reptiles'),
  ('Coronelle lisse',      'Coronella austriaca',   'Milieux secs et rocailleux. Souvent confondue avec la vipère mais inoffensive. Pupille ronde (vs verticale chez vipère).',              'Reptiles'),
  -- Légendaires
  ('Couleuvre vipérine',   'Natrix maura',          'Aquatique, en limite nord de répartition. Très rare en Oise, plus commune dans le sud de la France.',                                   'Reptiles')
) as s(common_name, scientific_name, description, category_name)
join public.categories c on c.name = s.category_name
on conflict (scientific_name) do nothing;


-- -------------------------------------------------------------
-- Statement 2 : INSERT public.species_zones
-- (le JOIN sur public.species trouve à la fois les espèces qu'on
-- vient d'insérer ET celles qui existaient déjà — idempotent)
-- -------------------------------------------------------------
insert into public.species_zones (species_id, zone_id, rarity)
select sp.id,
       (select id from public.zones where short_code = '60'),
       s.rarity::rarity
from (values
  -- Mammifères
  ('Vulpes vulpes',         'common'),
  ('Capreolus capreolus',   'common'),
  ('Sus scrofa',            'common'),
  ('Lepus europaeus',       'common'),
  ('Sciurus vulgaris',      'common'),
  ('Erinaceus europaeus',   'common'),
  ('Martes foina',          'rare'),
  ('Mustela nivalis',       'rare'),
  ('Meles meles',           'rare'),
  ('Cervus elaphus',        'rare'),
  ('Martes martes',         'epic'),
  ('Castor fiber',          'epic'),
  ('Mustela putorius',      'epic'),
  ('Felis silvestris',      'legendary'),
  ('Lutra lutra',           'legendary'),
  -- Reptiles
  ('Podarcis muralis',      'common'),
  ('Anguis fragilis',       'common'),
  ('Zootoca vivipara',      'rare'),
  ('Natrix helvetica',      'rare'),
  ('Vipera berus',          'epic'),
  ('Coronella austriaca',   'epic'),
  ('Natrix maura',          'legendary')
) as s(scientific_name, rarity)
join public.species sp on sp.scientific_name = s.scientific_name
on conflict (species_id, zone_id) do nothing;


-- =============================================================
-- Vérification post-migration
-- =============================================================
-- Espèces totales et par catégorie après cette migration :
--   select c.name, count(s.*) as nb
--   from public.categories c
--   left join public.species s on s.category_id = c.id
--   group by c.name, c.sort_order
--   order by c.sort_order;
--
-- Résultat attendu :
--   Oiseaux      | 35
--   Mammifères   | 15
--   Reptiles     |  7
--   Chiroptères  | 15
--   Total : 72 espèces curées sur Oise.
-- =============================================================
