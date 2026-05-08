-- =============================================================
-- Spotted — Migration 0005 : fix seed species_zones
-- =============================================================
-- Bug dans 0004 : les data-modifying CTE Postgres ne voient pas
-- les modifs des CTE soeurs. Le INSERT species_zones JOINait sur
-- public.species avant que les nouvelles espèces y soient visibles
-- → 0 lignes insérées dans species_zones.
--
-- Cette migration corrige le tir : les 50 espèces existent déjà
-- en BDD (l'INSERT species de 0004 a marché), il manque juste
-- les species_zones. Un mapping (scientific_name → rarity) suffit.
--
-- 0004 est aussi corrigée dans le repo pour les futurs clones.
-- =============================================================

with rarity_map (scientific_name, rarity) as (values
  -- Oiseaux
  ('Buteo buteo',                  'common'),
  ('Falco tinnunculus',            'common'),
  ('Accipiter nisus',              'rare'),
  ('Pernis apivorus',              'rare'),
  ('Falco subbuteo',               'epic'),
  ('Falco peregrinus',             'epic'),
  ('Milvus milvus',                'epic'),
  ('Pandion haliaetus',            'legendary'),
  ('Strix aluco',                  'common'),
  ('Tyto alba',                    'rare'),
  ('Asio otus',                    'rare'),
  ('Athene noctua',                'epic'),
  ('Asio flammeus',                'epic'),
  ('Bubo bubo',                    'legendary'),
  ('Ardea cinerea',                'common'),
  ('Ardea alba',                   'rare'),
  ('Egretta garzetta',             'rare'),
  ('Ciconia ciconia',              'rare'),
  ('Nycticorax nycticorax',        'epic'),
  ('Ciconia nigra',                'legendary'),
  ('Botaurus stellaris',           'legendary'),
  ('Dendrocopos major',            'common'),
  ('Picus viridis',                'common'),
  ('Dryocopus martius',            'rare'),
  ('Dendrocoptes medius',          'rare'),
  ('Alcedo atthis',                'rare'),
  ('Upupa epops',                  'epic'),
  ('Oriolus oriolus',              'rare'),
  ('Luscinia megarhynchos',        'rare'),
  ('Pyrrhula pyrrhula',            'rare'),
  ('Lanius collurio',              'epic'),
  ('Saxicola rubetra',             'epic'),
  ('Ficedula hypoleuca',           'rare'),
  ('Perdix perdix',                'rare'),
  ('Coturnix coturnix',            'epic'),
  -- Chiroptères
  ('Pipistrellus pipistrellus',    'common'),
  ('Pipistrellus kuhlii',          'common'),
  ('Eptesicus serotinus',          'common'),
  ('Nyctalus noctula',             'rare'),
  ('Nyctalus leisleri',            'rare'),
  ('Myotis daubentonii',           'rare'),
  ('Myotis mystacinus',            'rare'),
  ('Myotis nattereri',             'rare'),
  ('Myotis myotis',                'epic'),
  ('Myotis bechsteinii',           'epic'),
  ('Plecotus auritus',             'rare'),
  ('Plecotus austriacus',          'rare'),
  ('Barbastella barbastellus',     'epic'),
  ('Rhinolophus hipposideros',     'legendary'),
  ('Rhinolophus ferrumequinum',    'legendary')
)
insert into public.species_zones (species_id, zone_id, rarity)
select s.id,
       (select id from public.zones where short_code = '60'),
       rm.rarity::rarity
from rarity_map rm
join public.species s on s.scientific_name = rm.scientific_name
on conflict (species_id, zone_id) do nothing;

-- Vérification après exécution :
-- select count(*) from public.species_zones;  -- attendu : 50
