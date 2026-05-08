-- =============================================================
-- Spotted — Migration 0004 : seed espèces Oise (oiseaux + chiroptères)
-- =============================================================
-- 35 oiseaux + 15 chiroptères = 50 espèces curées pour Oise (60).
-- Mammifères + reptiles : à venir dans une migration ultérieure
-- (curation v1 manquante au 2026-05-08).
--
-- Pattern : table temporaire `tmp_species_seed` populée d'abord, puis
-- 2 INSERTs séparés (species, puis species_zones). Cette séparation
-- est nécessaire car les data-modifying CTE Postgres ne voient pas les
-- modifs des CTE soeurs — un INSERT species_zones dans le même WITH
-- ne verrait pas les nouvelles species (bug initial de cette migration).
--
-- Idempotence : "on conflict do nothing" sur scientific_name (species)
-- et sur la PK composite (species_zones). Re-jouer la migration ne
-- crée pas de doublon.
-- =============================================================

-- -------------------------------------------------------------
-- Table temporaire : la liste des 50 espèces avec leur catégorie + rareté
-- (droppée explicitement à la fin)
-- -------------------------------------------------------------
create temp table tmp_species_seed (
  common_name      text,
  scientific_name  text,
  description      text,
  rarity           text,
  category_name    text
);

insert into tmp_species_seed (common_name, scientific_name, description, rarity, category_name) values
  -- ===== OISEAUX =====
  -- Rapaces diurnes
  ('Buse variable',          'Buteo buteo',         'Le rapace le plus visible en plaine. Posée sur piquet ou en vol plané. Plumage très variable.', 'common',    'Oiseaux'),
  ('Faucon crécerelle',      'Falco tinnunculus',   'Petit faucon roussâtre. Vol stationnaire ("Saint-Esprit") au-dessus des bords de route.',     'common',    'Oiseaux'),
  ('Épervier d''Europe',     'Accipiter nisus',     'Bois et bocages. Vol rapide en alternance battements/glissés. Chasse de petits passereaux.',  'rare',      'Oiseaux'),
  ('Bondrée apivore',        'Pernis apivorus',     'Présente d''avril à septembre. Spécialiste des nids de guêpes. Queue plus longue que la buse.','rare',     'Oiseaux'),
  ('Faucon hobereau',        'Falco subbuteo',      'Petit faucon élégant aux ailes en faucille. Chasse hirondelles et grosses libellules en vol.','epic',      'Oiseaux'),
  ('Faucon pèlerin',         'Falco peregrinus',    'En recolonisation des falaises et grands édifices urbains. Stoop spectaculaire à 300 km/h.',  'epic',      'Oiseaux'),
  ('Milan royal',            'Milvus milvus',       'Surtout en passage migratoire. Queue échancrée rousse caractéristique.',                       'epic',      'Oiseaux'),
  ('Balbuzard pêcheur',      'Pandion haliaetus',   'En passage sur les grands plans d''eau. Plonge pour pêcher. Ventre blanc, masque facial sombre.','legendary','Oiseaux'),
  -- Rapaces nocturnes
  ('Chouette hulotte',       'Strix aluco',         'La plus répandue. Chant typique "hou-hou" des forêts. Souvent entendue, rarement vue.',         'common',    'Oiseaux'),
  ('Chouette effraie',       'Tyto alba',           'Granges, clochers, bâtiments isolés. Face en cœur blanche, chuintement strident.',              'rare',      'Oiseaux'),
  ('Hibou moyen-duc',        'Asio otus',           'Bois, lisières. Aigrettes visibles. Dortoirs hivernaux parfois communautaires.',                'rare',      'Oiseaux'),
  ('Chevêche d''Athéna',     'Athene noctua',       'Bocages, vieux vergers, granges isolées. Petite, trapue, parfois diurne sur un piquet. En déclin.','epic',   'Oiseaux'),
  ('Hibou des marais',       'Asio flammeus',       'Chasse en vol bas au-dessus de friches et marais, parfois en plein jour. Surtout hivernal.',   'epic',      'Oiseaux'),
  ('Grand-duc d''Europe',    'Bubo bubo',           'En recolonisation lente vers le nord. Énorme, aigrettes prononcées, chant grave et puissant.', 'legendary', 'Oiseaux'),
  -- Échassiers et aquatiques
  ('Héron cendré',           'Ardea cinerea',       'Toutes zones humides, parfois dans les champs. Grand, gris, posté immobile.',                  'common',    'Oiseaux'),
  ('Grande aigrette',        'Ardea alba',          'Hivernante régulière. Aussi grande que le héron cendré mais entièrement blanche.',             'rare',      'Oiseaux'),
  ('Aigrette garzette',      'Egretta garzetta',    'Plus petite, blanche, bec et pattes noirs, pieds jaunes. Bords d''eau peu profonde.',          'rare',      'Oiseaux'),
  ('Cigogne blanche',        'Ciconia ciconia',     'Nicheuse récente en Picardie. Grand oiseau noir et blanc, bec rouge.',                         'rare',      'Oiseaux'),
  ('Bihoreau gris',          'Nycticorax nycticorax','Petit héron trapu, gris et noir, actif au crépuscule. Bordures arborées des étangs.',         'epic',      'Oiseaux'),
  ('Cigogne noire',          'Ciconia nigra',       'En passage migratoire seulement. Discrète, forestière, bien plus rare que la blanche.',        'legendary', 'Oiseaux'),
  ('Butor étoilé',           'Botaurus stellaris',  'Très discret dans les grandes roselières. Chant "corne de brume" inimitable.',                 'legendary', 'Oiseaux'),
  -- Pics
  ('Pic épeiche',            'Dendrocopos major',   'Le pic classique, noir et blanc, calotte rouge (mâle). Tambourinage en cascade.',              'common',    'Oiseaux'),
  ('Pic vert',               'Picus viridis',       'Grand, vert et jaune, calotte rouge. Souvent au sol à chercher des fourmis. Cri ricanant.',    'common',    'Oiseaux'),
  ('Pic noir',               'Dryocopus martius',   'Le plus grand pic d''Europe. Tout noir, calotte rouge. Hêtraies anciennes (Compiègne, Halatte).','rare',     'Oiseaux'),
  ('Pic mar',                'Dendrocoptes medius', 'Confusion avec l''épeiche. Calotte rouge sur toute la tête. Vieilles chênaies.',               'rare',      'Oiseaux'),
  -- Passereaux remarquables
  ('Martin-pêcheur d''Europe','Alcedo atthis',      'L''éclair bleu turquoise au ras de l''eau. Cours d''eau lents et étangs. Iconique.',           'rare',      'Oiseaux'),
  ('Huppe fasciée',          'Upupa epops',         'Crête en éventail, vol papillonnant. Vergers, bocages chauds. Chant "houp-houp-houp" doux.',   'epic',      'Oiseaux'),
  ('Loriot d''Europe',       'Oriolus oriolus',     'Mâle jaune vif et noir, presque jamais vu (canopée), chant flûté inoubliable d''avril à juillet.','rare',   'Oiseaux'),
  ('Rossignol philomèle',    'Luscinia megarhynchos','Chant nocturne légendaire, oiseau brun discret. Buissons épais, lisières humides.',           'rare',      'Oiseaux'),
  ('Bouvreuil pivoine',      'Pyrrhula pyrrhula',   'Mâle au poitrail rose vif, calotte noire. Lisières, vergers. Sifflement triste très doux.',    'rare',      'Oiseaux'),
  ('Pie-grièche écorcheur',  'Lanius collurio',     'Empale ses proies sur les épines. Bocages avec haies épineuses. En déclin.',                   'epic',      'Oiseaux'),
  ('Tarier des prés',        'Saxicola rubetra',    'Prairies humides, friches. Sourcil blanc marqué. Espèce en fort déclin national.',             'epic',      'Oiseaux'),
  ('Gobemouche noir',        'Ficedula hypoleuca',  'Petit, mâle noir et blanc contrasté. Mieux observable en passage migratoire.',                 'rare',      'Oiseaux'),
  -- Galliformes
  ('Perdrix grise',          'Perdix perdix',       'Plaines céréalières. En fort déclin. Cri rauque, vol explosif au ras du sol.',                 'rare',      'Oiseaux'),
  ('Caille des blés',        'Coturnix coturnix',   'Présence détectée à l''oreille (chant "paye-tes-dettes"). Observation visuelle exceptionnelle.','epic',     'Oiseaux'),

  -- ===== CHIROPTÈRES =====
  -- Anthropophiles
  ('Pipistrelle commune',    'Pipistrellus pipistrellus', 'La plus abondante. Toute petite, voltige autour des lampadaires.',                       'common',    'Chiroptères'),
  ('Pipistrelle de Kuhl',    'Pipistrellus kuhlii',       'En forte expansion vers le nord. Très proche de la commune, liseré clair sur le bord de l''aile.','common','Chiroptères'),
  ('Sérotine commune',       'Eptesicus serotinus',       'Plus grande que les pipistrelles. Vol lent et puissant, chasse autour des lisières et lampadaires.','common','Chiroptères'),
  -- Noctules
  ('Noctule commune',        'Nyctalus noctula',          'Grande, vol rapide et haut juste après le coucher du soleil, en milieu ouvert. Gîte arboricole.','rare', 'Chiroptères'),
  ('Noctule de Leisler',     'Nyctalus leisleri',         'Plus petite que la noctule commune, vol comparable. Forestière.',                        'rare',      'Chiroptères'),
  -- Murins
  ('Murin de Daubenton',     'Myotis daubentonii',        'Chasse au ras de l''eau (étangs, rivières) — comportement très caractéristique.',         'rare',      'Chiroptères'),
  ('Murin à moustaches',     'Myotis mystacinus',         'Petit murin, vol vif en lisière, jardins, parcs.',                                       'rare',      'Chiroptères'),
  ('Murin de Natterer',      'Myotis nattereri',          'Forestier. Bord d''aile cilié visible en main.',                                         'rare',      'Chiroptères'),
  ('Grand Murin',            'Myotis myotis',             'Le plus grand murin. Hibernation en carrières (atteignable l''hiver). Forêts, prairies pâturées.','epic','Chiroptères'),
  ('Murin de Bechstein',     'Myotis bechsteinii',        'Spécialiste des vieilles forêts feuillues. Très grandes oreilles. Rare et menacé.',     'epic',      'Chiroptères'),
  -- Oreillards & Barbastelle
  ('Oreillard roux',         'Plecotus auritus',          'Oreilles immenses (presque aussi longues que le corps). Forestier.',                     'rare',      'Chiroptères'),
  ('Oreillard gris',         'Plecotus austriacus',       'Très proche du roux, plus anthropophile (combles).',                                     'rare',      'Chiroptères'),
  ('Barbastelle d''Europe',  'Barbastella barbastellus',  'Visage noir aplati, oreilles soudées sur le front. Vieilles forêts. Espèce sentinelle.', 'epic',      'Chiroptères'),
  -- Cavernicoles strictes
  ('Petit Rhinolophe',       'Rhinolophus hipposideros',  'S''enroule en boule dans son hibernation, suspendu, ailes refermées comme une cape. Cavernicole strict.','legendary','Chiroptères'),
  ('Grand Rhinolophe',       'Rhinolophus ferrumequinum', 'Idem, version XL. Feuille nasale en fer à cheval. Cavités, carrières en hivernage.',     'legendary', 'Chiroptères');

-- -------------------------------------------------------------
-- Statement 1 : INSERT public.species depuis tmp_species_seed
-- -------------------------------------------------------------
insert into public.species (common_name, scientific_name, category_id, description)
select t.common_name,
       t.scientific_name,
       c.id,
       t.description
from tmp_species_seed t
join public.categories c on c.name = t.category_name
on conflict (scientific_name) do nothing;

-- -------------------------------------------------------------
-- Statement 2 : INSERT public.species_zones (les species sont
-- maintenant visibles, le JOIN trouve bien leurs id)
-- -------------------------------------------------------------
insert into public.species_zones (species_id, zone_id, rarity)
select s.id,
       (select id from public.zones where short_code = '60'),
       t.rarity::rarity
from tmp_species_seed t
join public.species s on s.scientific_name = t.scientific_name
on conflict (species_id, zone_id) do nothing;

-- -------------------------------------------------------------
-- Cleanup
-- -------------------------------------------------------------
drop table tmp_species_seed;

-- =============================================================
-- Vérification
-- =============================================================
-- Espèces totales et par catégorie :
--   select c.name, count(s.*) as nb
--   from public.categories c
--   left join public.species s on s.category_id = c.id
--   group by c.name, c.sort_order
--   order by c.sort_order;
--
-- Résultat attendu :
--   Oiseaux      | 35
--   Mammifères   |  0
--   Reptiles     |  0
--   Chiroptères  | 15
--
-- Compte espèces × Oise (rareté) :
--   select sz.rarity, count(*)
--   from public.species_zones sz
--   join public.zones z on z.id = sz.zone_id
--   where z.short_code = '60'
--   group by sz.rarity
--   order by sz.rarity;
--
-- Résultat attendu (oiseaux + chiroptères) :
--   common    |  9
--   rare      | 22
--   epic      | 13
--   legendary |  6
--   Total : 50
-- =============================================================
