-- =============================================================
-- Spotted — Migration 0018 : seed territoire Savoie (73) + faune Vanoise
-- =============================================================
-- Ajoute le département de la Savoie (Parc national de la Vanoise) comme
-- 3e territoire curé. Contexte : randonnée GR5 Vanoise, 4 jours.
--
-- Écosystème radicalement différent d'Oise/Aisne (haute montagne alpine :
-- 1500-3500m). La plupart des espèces cibles ne sont pas encore en base
-- (bouquetin, chocard, gypaète, lagopède, etc.) — on les insère ici puis
-- on lie tout à la zone Savoie.
--
-- Répartition finale Savoie (40 espèces) :
--   - Oiseaux     : 24 (7 déjà en BDD + 17 nouvelles)
--   - Mammifères  :  9 (2 déjà en BDD + 7 nouvelles)
--   - Reptiles    :  5 (4 déjà en BDD + 1 nouvelle)
--   - Chiroptères :  2 (1 déjà en BDD + 1 nouvelle)
-- Total à insérer dans species : 26 nouvelles espèces alpines.
--
-- Choix de rareté : optique "randonneur GR5 Vanoise en été". Un chamois
-- ou une marmotte sont common (on les voit chaque jour), un bouquetin est
-- common aussi dans le parc (protégé depuis 1963). Le lagopède et le
-- gypaète restent legendary (obs exceptionnelle même sur le terrain).
--
-- Pattern : 3 statements auto-suffisants avec VALUES inline (cf. leçon 0009 :
-- pas de temp table, pgbouncer transaction mode peut couper la session
-- entre statements). Idempotent via `on conflict do nothing`.
-- =============================================================


-- -------------------------------------------------------------
-- Statement 1 : créer la zone Savoie (73) si elle n'existe pas
-- -------------------------------------------------------------
insert into public.zones (country_id, name, short_code, type)
select id, 'Savoie', '73', 'department'::zone_type
from public.countries
where iso_code = 'FR'
  and not exists (
    select 1 from public.zones z
    where z.short_code = '73' and z.country_id = countries.id
  );


-- -------------------------------------------------------------
-- Statement 2 : INSERT 26 nouvelles espèces alpines dans public.species
-- -------------------------------------------------------------
-- On inclut d'emblée `tips` (colonne ajoutée par migration 0012) — pas
-- besoin de backfill séparé pour ces nouvelles espèces.
insert into public.species (common_name, scientific_name, category_id, description, tips)
select s.common_name, s.scientific_name, c.id, s.description, s.tips
from (values

  -- ===== OISEAUX ALPINS =====

  -- Corvidés de montagne
  ('Grand corbeau',           'Corvus corax',
   'Le plus grand passereau d''Europe. Tout noir, queue cunéiforme, bec massif, vol majestueux souvent en couple. Cri rauque profond.',
   'Toute altitude, souvent au-dessus des crêtes ou près des cadavres. Vol en couple caractéristique, croassement grave "kro-kro".',
   'Oiseaux'),
  ('Chocard à bec jaune',     'Pyrrhocorax graculus',
   'Petit corvidé noir des hautes altitudes, bec jaune vif, pattes noires. En groupes bruyants autour des refuges et sommets.',
   'Omniprésent en Vanoise entre 1800 et 3000m. Refuges (Col de la Vanoise, Arpont) : ils viennent picorer les miettes. Cri sifflant.',
   'Oiseaux'),

  -- Rapaces
  ('Aigle royal',             'Aquila chrysaetos',
   'Grand rapace brun, envergure jusqu''à 2,3m, tête et nuque dorées chez l''adulte. Vol plané à grande hauteur au-dessus des crêtes.',
   'Repérer un point noir en vol circulaire au-dessus des crêtes rocheuses. Souvent chassé par les chocards. Vanoise = ~15 couples.',
   'Oiseaux'),
  ('Gypaète barbu',           'Gypaetus barbatus',
   'Vautour spectaculaire, envergure ~2,7m. Silhouette effilée, queue en losange, ventre orangé. Ré-introduit en Vanoise depuis 1986.',
   'Guette le ciel au-dessus des vallées d''alpage. Ailes très longues, queue en losange (≠ aigle). Souvent seul, vol lent et rectiligne.',
   'Oiseaux'),
  ('Vautour fauve',           'Gyps fulvus',
   'Grand vautour blond, tête blanchâtre nue, envergure ~2,5m. Vol en groupes serrés, plané en cercles. Estivant en Vanoise.',
   'Cherche les groupes qui tournoient en thermique au-dessus des alpages. Été surtout, remonte depuis les Baronnies/Verdon.',
   'Oiseaux'),

  -- Galliformes de montagne
  ('Lagopède alpin',          'Lagopus muta',
   'Perdrix arctique relique. Plumage blanc l''hiver, tacheté gris-brun l''été. Discret, se laisse approcher à quelques mètres.',
   'Étages alpin/nival (2200m+), pierriers et éboulis. Chercher au pied des blocs, souvent en couple. Mai-juin = mâle qui chante.',
   'Oiseaux'),
  ('Tétras lyre',             'Lyrurus tetrix',
   'Coq noir à queue en lyre (mâle), femelle brune tachetée. Étage subalpin, forêts claires de mélèzes et landes à rhododendrons.',
   'Aube au printemps (avril-mai) : chant de parade sur les places de chant. Sinon très discret, envol bruyant depuis les myrtilliers.',
   'Oiseaux'),
  ('Perdrix bartavelle',      'Alectoris graeca',
   'Perdrix des rocailles, gorge blanche cerclée de noir, flancs barrés. Espèce alpine méridionale, en régression.',
   'Versants ensoleillés rocheux entre 1200 et 2500m, souvent en groupes familiaux. Cri "tak-tak" métallique caractéristique.',
   'Oiseaux'),

  -- Falaises et parois
  ('Tichodrome échelette',    'Tichodroma muraria',
   'Passereau extraordinaire, gris avec ailes rouge carmin et blanc en vol. Escalade les falaises à la manière d''un papillon.',
   'Falaises calcaires, parois rocheuses ombragées (Grand Casse, gorges). Vol papillonnant qui révèle le rouge des ailes. Discret.',
   'Oiseaux'),

  -- Passereaux alpins
  ('Accenteur alpin',         'Prunella collaris',
   'Petit passereau trapu gris-brun, gorge blanche mouchetée de noir. Étages alpins, souvent près des refuges et sommets.',
   'Au-dessus de 2000m, rochers, névés. Approchable, vient parfois quémander aux abords des refuges. Chant grinçant discret.',
   'Oiseaux'),
  ('Niverolle alpine',        'Montifringilla nivalis',
   'Passereau des hautes altitudes, blanc et gris avec ailes noires et blanches contrastées en vol. Nichent en couloirs rocheux.',
   'Étages nival (2500m+), névés estivaux, cols élevés. Souvent en petits groupes. Ailes très blanches en vol = signature.',
   'Oiseaux'),
  ('Merle à plastron',        'Turdus torquatus',
   'Comme un merle noir mais avec un plastron blanc en croissant sur la poitrine. Étages subalpin à alpin.',
   'Landes à rhododendrons et pelouses d''altitude (1800-2500m). Chant flûté depuis un rocher ou un mélèze. Migre en Espagne l''hiver.',
   'Oiseaux'),
  ('Casse-noix moucheté',     'Nucifraga caryocatactes',
   'Corvidé forestier brun taché de blanc, bec long. Spécialiste des graines de pin cembro (arolle).',
   'Forêts d''arolles et mélézins (Vanoise = versant italien). Cri rauque, souvent en vol au-dessus de la canopée.',
   'Oiseaux'),
  ('Bec-croisé des sapins',   'Loxia curvirostra',
   'Passereau rouge (mâle) ou vert-jaune (femelle), bec aux mandibules croisées pour extraire graines de cônes.',
   'Forêts de résineux (mélèzes, épicéas), toute altitude. Petits groupes bavards en canopée. Écouter le "chip-chip" en vol.',
   'Oiseaux'),
  ('Rougequeue noir',         'Phoenicurus ochruros',
   'Petit passereau gris-noir, queue rousse permanente. Familier des refuges, granges d''alpage, villages de montagne.',
   'Toutes altitudes jusqu''à 3000m, autour des constructions humaines. Chant grinçant depuis un toit ou un rocher, tôt le matin.',
   'Oiseaux'),
  ('Traquet motteux',         'Oenanthe oenanthe',
   'Petit passereau des pelouses rases, croupion blanc éclatant en vol. Mâle au masque noir contrastant sur le gris.',
   'Alpages, pierriers, prairies pâturées de 1500 à 3000m. Perche sur pierre ou piquet. Vol bas ras du sol, croupion blanc = signature.',
   'Oiseaux'),
  ('Pipit spioncelle',        'Anthus spinoletta',
   'Petit passereau brun-gris, poitrine rosée en été. Pipit strictement montagnard, remplace le pipit farlouse en altitude.',
   'Alpages humides, abords de ruisseaux et lacs, 1800-2800m. Vol chanté typique : monte, se laisse tomber les ailes en V.',
   'Oiseaux'),


  -- ===== MAMMIFÈRES ALPINS =====

  -- Ongulés emblématiques
  ('Bouquetin des Alpes',     'Capra ibex',
   'Chèvre sauvage massive, cornes énormes et arquées (mâle) ou courtes (femelle). Emblème du Parc de la Vanoise, sauvé de l''extinction ici.',
   'Rochers et pelouses d''altitude (1800-3200m), très visible dans le parc. Femelles/jeunes en groupes, vieux mâles solitaires.',
   'Mammifères'),
  ('Chamois',                 'Rupicapra rupicapra',
   'Ongulé agile des pentes escarpées, cornes fines en crochet, masque facial noir et blanc contrasté. Plus vif que le bouquetin.',
   'Forêts et pelouses en pente (1000-3000m). En hardes de femelles/jeunes ou mâles solitaires. Descend en forêt l''hiver.',
   'Mammifères'),

  -- Rongeurs / lagomorphes
  ('Marmotte alpine',         'Marmota marmota',
   'Gros rongeur trapu (~5 kg), pelage brun-jaune. Vie en colonies familiales, hiberne 6 mois en terrier. Sifflement d''alerte.',
   'Alpages entre 1500 et 3000m, souvent visible dressée sur un rocher. Sifflement strident = alerte. Familles = 5 à 15 individus.',
   'Mammifères'),
  ('Lièvre variable',         'Lepus timidus',
   'Lièvre arctique relique glaciaire. Pelage brun-gris l''été, blanc pur l''hiver (sauf pointes d''oreilles). Étages alpins.',
   'Étages subalpin/alpin (1800m+), pierriers et landes. Très discret, crépusculaire. En régression face au lièvre commun qui remonte.',
   'Mammifères'),

  -- Carnivores
  ('Hermine',                 'Mustela erminea',
   'Petit mustélidé au corps allongé, brun dessus / blanc dessous l''été, tout blanc à bout de queue noir l''hiver.',
   'Alpages, pierriers, lisières. Curieuse, vient parfois observer les randonneurs. Chasse marmottons, campagnols. Toutes altitudes.',
   'Mammifères'),
  ('Loup gris',               'Canis lupus',
   'Grand canidé sauvage, pelage gris fauve, port de tête haut, allure élancée. Recolonisation naturelle depuis l''Italie (1992).',
   'Grand massif forestier, alpages. Rare de le voir : chercher traces, crottes, restes de proies. Vanoise = quelques meutes.',
   'Mammifères'),
  ('Lynx boréal',             'Lynx lynx',
   'Grand félin (~20 kg), oreilles à pinceau noir, courte queue à bout noir. Rarissime dans les Alpes françaises (~10 individus).',
   'Forêts denses de montagne. Quasi impossible à voir sans piège photo. Traces dans la neige = piste d''identification.',
   'Mammifères'),


  -- ===== REPTILES ALPINS =====

  ('Vipère aspic',            'Vipera aspis',
   'Vipère du sud, tête triangulaire nette, museau retroussé. Zigzag dorsal souvent moins marqué que la péliade.',
   'Coteaux ensoleillés, éboulis, murets de pierres sèches (jusqu''à 2000m). Sortie mars-octobre. Prudence, venimeuse.',
   'Reptiles'),


  -- ===== CHIROPTÈRES ALPINS =====

  ('Sérotine de Nilsson',     'Eptesicus nilssonii',
   'Seule chauve-souris strictement montagnarde de France. Pelage brun-doré aux pointes claires. Vol lent en lisière.',
   'Étages subalpins (1000-2000m). Chasse en lisière forestière, autour des chalets d''alpage. Détecteur à ~28 kHz.',
   'Chiroptères')

) as s(common_name, scientific_name, description, tips, category_name)
join public.categories c on c.name = s.category_name
on conflict (scientific_name) do nothing;


-- -------------------------------------------------------------
-- Statement 3 : lier les 40 espèces Vanoise à la zone Savoie
-- -------------------------------------------------------------
-- Inclut à la fois les espèces existantes (déjà en BDD via seeds Oise/Aisne)
-- ET les nouvelles alpines insérées ci-dessus.
insert into public.species_zones (species_id, zone_id, rarity)
select sp.id,
       (select id from public.zones where short_code = '73'),
       s.rarity::rarity
from (values

  -- ===== OISEAUX =====
  -- Déjà en BDD (générique, également présent en Vanoise)
  ('Buteo buteo',                 'common'),    -- Buse variable, plaines et vallées
  ('Falco tinnunculus',           'common'),    -- Faucon crécerelle, versants ouverts
  ('Falco peregrinus',            'epic'),      -- Faucon pèlerin, falaises
  ('Dendrocopos major',           'common'),    -- Pic épeiche, forêts inférieures
  ('Dryocopus martius',           'common'),    -- Pic noir, hêtraies-sapinières
  ('Strix aluco',                 'common'),    -- Chouette hulotte, forêts
  ('Ficedula hypoleuca',          'rare'),      -- Gobemouche noir, mélézins clairs
  -- Nouvelles alpines
  ('Corvus corax',                'common'),    -- Grand corbeau
  ('Pyrrhocorax graculus',        'common'),    -- Chocard à bec jaune, omniprésent
  ('Aquila chrysaetos',           'epic'),      -- Aigle royal
  ('Gypaetus barbatus',           'legendary'), -- Gypaète barbu, réintroduit
  ('Gyps fulvus',                 'epic'),      -- Vautour fauve, estivant
  ('Lagopus muta',                'legendary'), -- Lagopède alpin, très discret
  ('Lyrurus tetrix',              'epic'),      -- Tétras lyre
  ('Alectoris graeca',            'epic'),      -- Perdrix bartavelle
  ('Tichodroma muraria',          'epic'),      -- Tichodrome échelette
  ('Prunella collaris',           'rare'),      -- Accenteur alpin
  ('Montifringilla nivalis',      'rare'),      -- Niverolle alpine
  ('Turdus torquatus',            'rare'),      -- Merle à plastron
  ('Nucifraga caryocatactes',     'rare'),      -- Casse-noix moucheté
  ('Loxia curvirostra',           'common'),    -- Bec-croisé des sapins
  ('Phoenicurus ochruros',        'common'),    -- Rougequeue noir, refuges
  ('Oenanthe oenanthe',           'common'),    -- Traquet motteux, alpages
  ('Anthus spinoletta',           'common'),    -- Pipit spioncelle, alpages

  -- ===== MAMMIFÈRES =====
  -- Déjà en BDD
  ('Vulpes vulpes',               'common'),    -- Renard roux, toutes altitudes
  ('Capreolus capreolus',         'common'),    -- Chevreuil, forêts inférieures
  -- Nouvelles alpines
  ('Capra ibex',                  'common'),    -- Bouquetin, emblème Vanoise
  ('Rupicapra rupicapra',         'common'),    -- Chamois
  ('Marmota marmota',             'common'),    -- Marmotte, omniprésente en alpage
  ('Lepus timidus',               'rare'),      -- Lièvre variable
  ('Mustela erminea',             'rare'),      -- Hermine
  ('Canis lupus',                 'legendary'), -- Loup, meutes présentes
  ('Lynx lynx',                   'legendary'), -- Lynx, ~10 individus dans les Alpes

  -- ===== REPTILES =====
  -- Déjà en BDD
  ('Podarcis muralis',            'common'),    -- Lézard des murailles, basses altitudes
  ('Anguis fragilis',             'common'),    -- Orvet fragile, forêts
  ('Zootoca vivipara',            'common'),    -- Lézard vivipare, très à l'aise en altitude
  ('Vipera berus',                'epic'),      -- Vipère péliade, spécifique alpin
  -- Nouvelle
  ('Vipera aspis',                'rare'),      -- Vipère aspic, basses altitudes

  -- ===== CHIROPTÈRES =====
  -- Déjà en BDD
  ('Pipistrellus pipistrellus',   'common'),    -- Pipistrelle commune, jusqu'à 2000m
  -- Nouvelle
  ('Eptesicus nilssonii',         'rare')       -- Sérotine de Nilsson, seule chiro strictement alpine

) as s(scientific_name, rarity)
join public.species sp on sp.scientific_name = s.scientific_name
on conflict (species_id, zone_id) do nothing;


-- =============================================================
-- Vérifications post-migration
-- =============================================================
-- Compter les espèces par catégorie sur la zone Savoie :
--   select c.name, count(*)
--   from public.species_zones sz
--   join public.zones z on z.id = sz.zone_id
--   join public.species sp on sp.id = sz.species_id
--   join public.categories c on c.id = sp.category_id
--   where z.short_code = '73'
--   group by c.name, c.sort_order
--   order by c.sort_order;
--
-- Résultat attendu :
--   Oiseaux     : 24
--   Mammifères  :  9
--   Reptiles    :  5
--   Chiroptères :  2
--   Total       : 40
-- =============================================================
