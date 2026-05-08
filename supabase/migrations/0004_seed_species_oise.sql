-- =============================================================
-- Spotted — Migration 0004 : seed espèces Oise (oiseaux + chiroptères)
-- =============================================================
-- 35 oiseaux + 15 chiroptères = 50 espèces curées pour Oise (60).
-- Mammifères + reptiles : à venir dans une migration ultérieure
-- (curation v1 manquante au 2026-05-08).
--
-- Idempotence : "on conflict do nothing" sur scientific_name (unique)
-- pour species, et sur la PK composite (species_id, zone_id) pour
-- species_zones. Re-jouer la migration ne crée pas de doublon.
--
-- Pattern : CTE `species_data` (VALUES inline) → INSERT species via
-- data-modifying CTE → INSERT species_zones via JOIN sur scientific_name.
-- =============================================================

-- -------------------------------------------------------------
-- Bloc 1 : OISEAUX (35 espèces)
-- -------------------------------------------------------------
with species_data (common_name, scientific_name, description, rarity) as (values
  -- Rapaces diurnes
  ('Buse variable',          'Buteo buteo',         'Le rapace le plus visible en plaine. Posée sur piquet ou en vol plané. Plumage très variable.', 'common'),
  ('Faucon crécerelle',      'Falco tinnunculus',   'Petit faucon roussâtre. Vol stationnaire ("Saint-Esprit") au-dessus des bords de route.', 'common'),
  ('Épervier d''Europe',     'Accipiter nisus',     'Bois et bocages. Vol rapide en alternance battements/glissés. Chasse de petits passereaux.', 'rare'),
  ('Bondrée apivore',        'Pernis apivorus',     'Présente d''avril à septembre. Spécialiste des nids de guêpes. Queue plus longue que la buse.', 'rare'),
  ('Faucon hobereau',        'Falco subbuteo',      'Petit faucon élégant aux ailes en faucille. Chasse hirondelles et grosses libellules en vol.', 'epic'),
  ('Faucon pèlerin',         'Falco peregrinus',    'En recolonisation des falaises et grands édifices urbains. Stoop spectaculaire à 300 km/h.', 'epic'),
  ('Milan royal',            'Milvus milvus',       'Surtout en passage migratoire. Queue échancrée rousse caractéristique.', 'epic'),
  ('Balbuzard pêcheur',      'Pandion haliaetus',   'En passage sur les grands plans d''eau. Plonge pour pêcher. Ventre blanc, masque facial sombre.', 'legendary'),
  -- Rapaces nocturnes
  ('Chouette hulotte',       'Strix aluco',         'La plus répandue. Chant typique "hou-hou" des forêts. Souvent entendue, rarement vue.', 'common'),
  ('Chouette effraie',       'Tyto alba',           'Granges, clochers, bâtiments isolés. Face en cœur blanche, chuintement strident.', 'rare'),
  ('Hibou moyen-duc',        'Asio otus',           'Bois, lisières. Aigrettes visibles. Dortoirs hivernaux parfois communautaires.', 'rare'),
  ('Chevêche d''Athéna',     'Athene noctua',       'Bocages, vieux vergers, granges isolées. Petite, trapue, parfois diurne sur un piquet. En déclin.', 'epic'),
  ('Hibou des marais',       'Asio flammeus',       'Chasse en vol bas au-dessus de friches et marais, parfois en plein jour. Surtout hivernal.', 'epic'),
  ('Grand-duc d''Europe',    'Bubo bubo',           'En recolonisation lente vers le nord. Énorme, aigrettes prononcées, chant grave et puissant.', 'legendary'),
  -- Échassiers et aquatiques
  ('Héron cendré',           'Ardea cinerea',       'Toutes zones humides, parfois dans les champs. Grand, gris, posté immobile.', 'common'),
  ('Grande aigrette',        'Ardea alba',          'Hivernante régulière. Aussi grande que le héron cendré mais entièrement blanche.', 'rare'),
  ('Aigrette garzette',      'Egretta garzetta',    'Plus petite, blanche, bec et pattes noirs, pieds jaunes. Bords d''eau peu profonde.', 'rare'),
  ('Cigogne blanche',        'Ciconia ciconia',     'Nicheuse récente en Picardie. Grand oiseau noir et blanc, bec rouge.', 'rare'),
  ('Bihoreau gris',          'Nycticorax nycticorax','Petit héron trapu, gris et noir, actif au crépuscule. Bordures arborées des étangs.', 'epic'),
  ('Cigogne noire',          'Ciconia nigra',       'En passage migratoire seulement. Discrète, forestière, bien plus rare que la blanche.', 'legendary'),
  ('Butor étoilé',           'Botaurus stellaris',  'Très discret dans les grandes roselières. Chant "corne de brume" inimitable.', 'legendary'),
  -- Pics
  ('Pic épeiche',            'Dendrocopos major',   'Le pic classique, noir et blanc, calotte rouge (mâle). Tambourinage en cascade.', 'common'),
  ('Pic vert',               'Picus viridis',       'Grand, vert et jaune, calotte rouge. Souvent au sol à chercher des fourmis. Cri ricanant.', 'common'),
  ('Pic noir',               'Dryocopus martius',   'Le plus grand pic d''Europe. Tout noir, calotte rouge. Hêtraies anciennes (Compiègne, Halatte).', 'rare'),
  ('Pic mar',                'Dendrocoptes medius', 'Confusion avec l''épeiche. Calotte rouge sur toute la tête. Vieilles chênaies.', 'rare'),
  -- Passereaux remarquables
  ('Martin-pêcheur d''Europe','Alcedo atthis',      'L''éclair bleu turquoise au ras de l''eau. Cours d''eau lents et étangs. Iconique.', 'rare'),
  ('Huppe fasciée',          'Upupa epops',         'Crête en éventail, vol papillonnant. Vergers, bocages chauds. Chant "houp-houp-houp" doux.', 'epic'),
  ('Loriot d''Europe',       'Oriolus oriolus',     'Mâle jaune vif et noir, presque jamais vu (canopée), chant flûté inoubliable d''avril à juillet.', 'rare'),
  ('Rossignol philomèle',    'Luscinia megarhynchos','Chant nocturne légendaire, oiseau brun discret. Buissons épais, lisières humides.', 'rare'),
  ('Bouvreuil pivoine',      'Pyrrhula pyrrhula',   'Mâle au poitrail rose vif, calotte noire. Lisières, vergers. Sifflement triste très doux.', 'rare'),
  ('Pie-grièche écorcheur',  'Lanius collurio',     'Empale ses proies sur les épines. Bocages avec haies épineuses. En déclin.', 'epic'),
  ('Tarier des prés',        'Saxicola rubetra',    'Prairies humides, friches. Sourcil blanc marqué. Espèce en fort déclin national.', 'epic'),
  ('Gobemouche noir',        'Ficedula hypoleuca',  'Petit, mâle noir et blanc contrasté. Mieux observable en passage migratoire.', 'rare'),
  -- Galliformes
  ('Perdrix grise',          'Perdix perdix',       'Plaines céréalières. En fort déclin. Cri rauque, vol explosif au ras du sol.', 'rare'),
  ('Caille des blés',        'Coturnix coturnix',   'Présence détectée à l''oreille (chant "paye-tes-dettes"). Observation visuelle exceptionnelle.', 'epic')
),
ins_species as (
  insert into public.species (common_name, scientific_name, category_id, description)
  select sd.common_name,
         sd.scientific_name,
         (select id from public.categories where name = 'Oiseaux'),
         sd.description
  from species_data sd
  on conflict (scientific_name) do nothing
  returning id
)
insert into public.species_zones (species_id, zone_id, rarity)
select s.id,
       (select id from public.zones where short_code = '60'),
       sd.rarity::rarity
from species_data sd
join public.species s on s.scientific_name = sd.scientific_name
on conflict (species_id, zone_id) do nothing;

-- -------------------------------------------------------------
-- Bloc 2 : CHIROPTÈRES (15 espèces)
-- -------------------------------------------------------------
with species_data (common_name, scientific_name, description, rarity) as (values
  -- Anthropophiles
  ('Pipistrelle commune',    'Pipistrellus pipistrellus', 'La plus abondante. Toute petite, voltige autour des lampadaires.', 'common'),
  ('Pipistrelle de Kuhl',    'Pipistrellus kuhlii',       'En forte expansion vers le nord. Très proche de la commune, liseré clair sur le bord de l''aile.', 'common'),
  ('Sérotine commune',       'Eptesicus serotinus',       'Plus grande que les pipistrelles. Vol lent et puissant, chasse autour des lisières et lampadaires.', 'common'),
  -- Noctules
  ('Noctule commune',        'Nyctalus noctula',          'Grande, vol rapide et haut juste après le coucher du soleil, en milieu ouvert. Gîte arboricole.', 'rare'),
  ('Noctule de Leisler',     'Nyctalus leisleri',         'Plus petite que la noctule commune, vol comparable. Forestière.', 'rare'),
  -- Murins
  ('Murin de Daubenton',     'Myotis daubentonii',        'Chasse au ras de l''eau (étangs, rivières) — comportement très caractéristique.', 'rare'),
  ('Murin à moustaches',     'Myotis mystacinus',         'Petit murin, vol vif en lisière, jardins, parcs.', 'rare'),
  ('Murin de Natterer',      'Myotis nattereri',          'Forestier. Bord d''aile cilié visible en main.', 'rare'),
  ('Grand Murin',            'Myotis myotis',             'Le plus grand murin. Hibernation en carrières (atteignable l''hiver). Forêts, prairies pâturées.', 'epic'),
  ('Murin de Bechstein',     'Myotis bechsteinii',        'Spécialiste des vieilles forêts feuillues. Très grandes oreilles. Rare et menacé.', 'epic'),
  -- Oreillards & Barbastelle
  ('Oreillard roux',         'Plecotus auritus',          'Oreilles immenses (presque aussi longues que le corps). Forestier.', 'rare'),
  ('Oreillard gris',         'Plecotus austriacus',       'Très proche du roux, plus anthropophile (combles).', 'rare'),
  ('Barbastelle d''Europe',  'Barbastella barbastellus',  'Visage noir aplati, oreilles soudées sur le front. Vieilles forêts. Espèce sentinelle.', 'epic'),
  -- Cavernicoles strictes
  ('Petit Rhinolophe',       'Rhinolophus hipposideros',  'S''enroule en boule dans son hibernation, suspendu, ailes refermées comme une cape. Cavernicole strict.', 'legendary'),
  ('Grand Rhinolophe',       'Rhinolophus ferrumequinum', 'Idem, version XL. Feuille nasale en fer à cheval. Cavités, carrières en hivernage.', 'legendary')
),
ins_species as (
  insert into public.species (common_name, scientific_name, category_id, description)
  select sd.common_name,
         sd.scientific_name,
         (select id from public.categories where name = 'Chiroptères'),
         sd.description
  from species_data sd
  on conflict (scientific_name) do nothing
  returning id
)
insert into public.species_zones (species_id, zone_id, rarity)
select s.id,
       (select id from public.zones where short_code = '60'),
       sd.rarity::rarity
from species_data sd
join public.species s on s.scientific_name = sd.scientific_name
on conflict (species_id, zone_id) do nothing;

-- =============================================================
-- Vérification
-- =============================================================
-- Espèces totales et par catégorie :
--   select c.name, count(s.*) as nb
--   from public.categories c
--   left join public.species s on s.category_id = c.id
--   group by c.name
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
