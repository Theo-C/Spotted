-- =============================================================
-- Spotted — Migration 0012 : ajout colonne `tips` (Pour la débusquer)
-- =============================================================
-- Le wireframe v5 prévoit une carte "Pour la débusquer" sur la fiche
-- détail des espèces non encore observées — un conseil terrain court
-- (où / quand / comment chercher).
--
-- Ce field manquait au schéma. On l'ajoute ici et on le rétro-alimente
-- pour les 72 espèces curées (35 oiseaux + 15 chiroptères + 15 mammifères
-- + 7 reptiles).
--
-- Style des tips : 1-2 phrases, ~120 caractères, naturaliste pratique.
-- Mentionne quand pertinent : habitat précis, saison, comportement,
-- moment de la journée, indices indirects (chant, traces).
-- =============================================================

-- Colonne text optionnelle. Idempotent grâce à `if not exists` (PG 9.6+).
alter table public.species
  add column if not exists tips text;

-- -------------------------------------------------------------
-- Backfill des tips pour les 72 espèces existantes
-- -------------------------------------------------------------
-- Chaque UPDATE est filtré sur scientific_name (clé naturelle stable).
-- Idempotent : ré-applique le même texte sans créer de doublon.

update public.species set tips = case scientific_name

  -- ===== OISEAUX =====
  -- Rapaces diurnes
  when 'Buteo buteo'              then 'Posée sur piquets ou poteaux en bordure de champs. Vol plané en cercles à mi-hauteur. Toute l''année, plaine ouverte.'
  when 'Falco tinnunculus'        then 'Vol stationnaire « Saint-Esprit » au-dessus des bordures de route. Cherche-la en zones agricoles, surtout au printemps.'
  when 'Accipiter nisus'          then 'Vol vif et furtif entre les arbres, alterné battements/glissés. Bordures de bois et bosquets, traque les passereaux.'
  when 'Pernis apivorus'          then 'Présente d''avril à septembre. Vol plané similaire à la buse mais queue plus longue. Forêts et lisières.'
  when 'Falco subbuteo'           then 'Chasse hirondelles et grosses libellules en vol au crépuscule. Étangs et zones humides en été.'
  when 'Falco peregrinus'         then 'Stoop spectaculaire depuis falaises ou grands édifices urbains (cathédrale de Laon, hauts d''immeubles). Toute l''année.'
  when 'Milvus milvus'            then 'Surtout en passage migratoire (mars-avril, sept-oct). Queue échancrée rousse en vol plané.'
  when 'Pandion haliaetus'        then 'Au-dessus des grands plans d''eau en passage. Plonge en piqué pour capturer un poisson.'
  -- Rapaces nocturnes
  when 'Strix aluco'              then 'Le « hou-hou » typique des forêts au crépuscule et la nuit. Vieux arbres creux. Toute l''année.'
  when 'Tyto alba'                then 'Vole bas et silencieusement la nuit autour des granges, clochers, bâtiments isolés. Chuintement strident.'
  when 'Asio otus'                then 'Bois et lisières au crépuscule. Dortoirs hivernaux parfois communautaires (jusqu''à 30 individus dans un sapin).'
  when 'Athene noctua'            then 'Bocages, vieux vergers, granges isolées. Souvent diurne sur un piquet en début ou fin de journée.'
  when 'Asio flammeus'            then 'Chasse en vol bas au-dessus de friches et marais, parfois en plein jour. Surtout hivernal (oct-mars).'
  when 'Bubo bubo'                then 'Crépuscule et nuit, perché sur un arbre dominant ou un rocher. Chant grave et puissant « hou-hou ».'
  -- Échassiers et aquatiques
  when 'Ardea cinerea'            then 'Posté immobile au bord des étangs, fossés, parfois en plein champ. Vol lent et lourd, cou replié. Toute l''année.'
  when 'Ardea alba'               then 'Hivernante régulière (oct-mars) sur les zones humides. Aussi grande que le héron cendré mais entièrement blanche.'
  when 'Egretta garzetta'         then 'Bords d''eau peu profonde, agitée et active. Cherche les pieds jaunes sur pattes noires.'
  when 'Ciconia ciconia'          then 'Nicheuse récente en Picardie. Grand oiseau noir et blanc, posé en plaine humide ou en vol plané majestueux.'
  when 'Nycticorax nycticorax'    then 'Actif au crépuscule. Petit héron trapu posté dans la végétation arborée des étangs.'
  when 'Ciconia nigra'            then 'En passage migratoire seulement (avril, sept). Discrète, forestière, plus petite et noire que la blanche.'
  when 'Botaurus stellaris'       then 'Très discret dans les grandes roselières (Marais de la Souche pour l''Aisne). Chant « corne de brume » au printemps.'
  -- Pics
  when 'Dendrocopos major'        then 'Tambourinage en cascade. Présent toute l''année dans les bois et parcs. Le pic noir et blanc le plus visible.'
  when 'Picus viridis'            then 'Souvent au sol à chercher des fourmis. Cri ricanant « ki-ki-ki ». Lisières, parcs, prairies arborées.'
  when 'Dryocopus martius'        then 'Hêtraies anciennes (Compiègne, Halatte, St-Gobain). Tambourinage très puissant. Tout noir, calotte rouge.'
  when 'Dendrocoptes medius'      then 'Vieilles chênaies (forêt de Retz). Calotte rouge entière, pas de moustache fermée. Plus petit que l''épeiche.'
  -- Passereaux remarquables
  when 'Alcedo atthis'            then 'Cours d''eau lents et étangs. L''éclair bleu turquoise au ras de l''eau, posé sur une branche basse.'
  when 'Upupa epops'              then 'Bocages chauds, vergers ouverts. Vol papillonnant, crête déployée à l''envol. Chant « houp-houp-houp » en avril-juin.'
  when 'Oriolus oriolus'          then 'Mâle jaune vif et noir, presque invisible (canopée). Chant flûté inoubliable d''avril à juillet en bordure de bois.'
  when 'Luscinia megarhynchos'    then 'Chant nocturne légendaire d''avril à juin. Buissons épais et lisières humides. Oiseau brun très discret.'
  when 'Pyrrhula pyrrhula'        then 'Lisières, vergers, jardins. Sifflement triste très doux. Le mâle au poitrail rose vif est inoubliable.'
  when 'Lanius collurio'          then 'Bocages avec haies épineuses. Empale ses proies sur les épines (insectes, lézards). Mai à août.'
  when 'Saxicola rubetra'         then 'Prairies humides et friches. Sourcil blanc marqué. Espèce en fort déclin — chaque obs compte.'
  when 'Ficedula hypoleuca'       then 'Mieux observable en passage migratoire (avril-mai, août-sept). Mâle noir et blanc contrasté.'
  -- Galliformes
  when 'Perdix perdix'            then 'Plaines céréalières. Vol explosif au ras du sol quand on s''en approche. Cri rauque. En fort déclin.'
  when 'Coturnix coturnix'        then 'Présence détectée à l''oreille (chant « paye-tes-dettes » à 3 syllabes). Observation visuelle exceptionnelle.'

  -- ===== CHIROPTÈRES =====
  when 'Pipistrellus pipistrellus' then 'Voltige autour des lampadaires au crépuscule. Présente partout en milieu urbain et péri-urbain.'
  when 'Pipistrellus kuhlii'      then 'En forte expansion vers le nord. Voltige aussi autour des lampadaires, liseré clair sur le bord de l''aile.'
  when 'Eptesicus serotinus'      then 'Vol lent et puissant, plus grande que les pipistrelles. Chasse autour des lisières et lampadaires.'
  when 'Nyctalus noctula'         then 'Vol rapide et haut juste après le coucher du soleil, en milieu ouvert. Gîtes arboricoles.'
  when 'Nyctalus leisleri'        then 'Forestière. Plus petite que la noctule commune, vol comparable. Vieux arbres à cavités.'
  when 'Myotis daubentonii'       then 'Chasse au ras de l''eau (étangs, rivières) au crépuscule. Comportement très caractéristique.'
  when 'Myotis mystacinus'        then 'Vol vif en lisière, jardins, parcs. Petit murin discret.'
  when 'Myotis nattereri'         then 'Forestier. Bord d''aile cilié visible en main (capture filet par chiroptérologues).'
  when 'Myotis myotis'            then 'Hibernation en carrières (visites guidées hivernales). Forêts et prairies pâturées en été.'
  when 'Myotis bechsteinii'       then 'Spécialiste des vieilles forêts feuillues. Très grandes oreilles. Rare et menacé.'
  when 'Plecotus auritus'         then 'Forestier. Oreilles immenses presque aussi longues que le corps. Vol lent et papillonnant.'
  when 'Plecotus austriacus'      then 'Plus anthropophile que le roux, gîte en combles. Très proche visuellement.'
  when 'Barbastella barbastellus' then 'Vieilles forêts (St-Gobain). Visage noir aplati, oreilles soudées sur le front. Espèce sentinelle.'
  when 'Rhinolophus hipposideros' then 'Cavernicole strict. S''enroule en boule en hibernation, ailes refermées comme une cape.'
  when 'Rhinolophus ferrumequinum' then 'Comme le Petit mais en XL. Feuille nasale en fer à cheval. Cavités, carrières en hivernage.'

  -- ===== MAMMIFÈRES =====
  when 'Vulpes vulpes'            then 'Crépuscule en bordure de champs et lisières. Parfois en plein jour ou en milieu urbain. Toute l''année.'
  when 'Capreolus capreolus'      then 'Lisières et bocages à l''aube et au crépuscule. Aboiement caractéristique au rut (juillet-août).'
  when 'Sus scrofa'               then 'Boutis (terre retournée) et empreintes très visibles. Plutôt nocturne — observation directe rare et aux heures fraîches.'
  when 'Lepus europaeus'          then 'Plaines céréalières et prairies. Plus actif au crépuscule. Plus grand et élancé que le lapin, oreilles à pointe noire.'
  when 'Sciurus vulgaris'         then 'Forêts feuillues et parcs urbains. Acrobate dans les arbres en journée. Toute l''année.'
  when 'Erinaceus europaeus'      then 'Crépuscule et nuit dans jardins et bocages. Ronflements caractéristiques. Hiberne d''octobre à mars.'
  when 'Martes foina'             then 'Crépuscule et nuit, proche des habitations (granges, combles). Gorge blanche en bavette.'
  when 'Mustela nivalis'          then 'Très vif, traverse rapidement chemins et lisières. Chasse les campagnols. Difficile à capturer en obs.'
  when 'Meles meles'              then 'Nocturne. Cherche les terriers profonds en lisière de bois. Affût en soirée d''avril à juin.'
  when 'Cervus elaphus'           then 'Grandes forêts domaniales (St-Gobain, Retz, Compiègne, Halatte). Brame spectaculaire en septembre-octobre.'
  when 'Martes martes'            then 'Strictement forestière (vieilles futaies). Crépuscule et nuit. Très discrète — indices (crottes au milieu des chemins) plus que vue directe.'
  when 'Castor fiber'             then 'Indices avant l''animal : arbres rongés en sablier, huttes, barrages le long de l''Oise et de l''Aisne. Crépuscule à la nuit.'
  when 'Mustela putorius'         then 'Zones humides, bocages. Nocturne. Souvent vu mort sur les routes — espèce en fort déclin.'
  when 'Felis silvestris'         then 'Lisières de grandes forêts, surtout l''aube. Gris tigré, queue épaisse à anneaux noirs nets. Très méfiant.'
  when 'Lutra lutra'              then 'Cherche les épreintes (crottes parfumées de poisson) sur les rochers en bord de cours d''eau. Vue directe rarissime.'

  -- ===== REPTILES =====
  when 'Podarcis muralis'         then 'Murs ensoleillés, jardins, ruines. Vif, mi-journée chaude entre mars et octobre.'
  when 'Anguis fragilis'          then 'Sous pierres, bois, compost. Brun cuivré brillant, lézard apode souvent confondu avec un serpent.'
  when 'Zootoca vivipara'         then 'Tourbières et prairies humides fraîches. Plus discret que le murailles, brun-vert. Avril à octobre.'
  when 'Natrix helvetica'         then 'Zones humides, étangs, fossés. Collier jaune et noir derrière la tête. Inoffensive, fuit à l''approche.'
  when 'Vipera berus'             then 'Landes humides forestières et lisières exposées. Zigzag dorsal noir. Avril à octobre, prudence.'
  when 'Coronella austriaca'      then 'Milieux secs et rocailleux. Pupille ronde (la vipère a la pupille verticale). Inoffensive.'
  when 'Natrix maura'             then 'Aquatique, en limite nord. Très rare en Oise. Observation surtout sud du département en été.'

  else tips
end
where scientific_name in (
  -- Liste des espèces concernées (sécurité — empêche un effacement
  -- accidentel des tips d'autres lignes que l'on ajouterait plus tard).
  'Buteo buteo','Falco tinnunculus','Accipiter nisus','Pernis apivorus',
  'Falco subbuteo','Falco peregrinus','Milvus milvus','Pandion haliaetus',
  'Strix aluco','Tyto alba','Asio otus','Athene noctua','Asio flammeus',
  'Bubo bubo','Ardea cinerea','Ardea alba','Egretta garzetta',
  'Ciconia ciconia','Nycticorax nycticorax','Ciconia nigra','Botaurus stellaris',
  'Dendrocopos major','Picus viridis','Dryocopus martius','Dendrocoptes medius',
  'Alcedo atthis','Upupa epops','Oriolus oriolus','Luscinia megarhynchos',
  'Pyrrhula pyrrhula','Lanius collurio','Saxicola rubetra','Ficedula hypoleuca',
  'Perdix perdix','Coturnix coturnix',
  'Pipistrellus pipistrellus','Pipistrellus kuhlii','Eptesicus serotinus',
  'Nyctalus noctula','Nyctalus leisleri','Myotis daubentonii','Myotis mystacinus',
  'Myotis nattereri','Myotis myotis','Myotis bechsteinii','Plecotus auritus',
  'Plecotus austriacus','Barbastella barbastellus','Rhinolophus hipposideros',
  'Rhinolophus ferrumequinum',
  'Vulpes vulpes','Capreolus capreolus','Sus scrofa','Lepus europaeus',
  'Sciurus vulgaris','Erinaceus europaeus','Martes foina','Mustela nivalis',
  'Meles meles','Cervus elaphus','Martes martes','Castor fiber',
  'Mustela putorius','Felis silvestris','Lutra lutra',
  'Podarcis muralis','Anguis fragilis','Zootoca vivipara','Natrix helvetica',
  'Vipera berus','Coronella austriaca','Natrix maura'
);

-- =============================================================
-- Vérification post-migration
-- =============================================================
-- Doit renvoyer 72 (toutes les espèces curées ont leur tips).
-- select count(*) from public.species where tips is not null;
--
-- Si tu veux jeter un œil à un échantillon :
-- select common_name, tips from public.species
-- where tips is not null
-- order by random() limit 5;
-- =============================================================
