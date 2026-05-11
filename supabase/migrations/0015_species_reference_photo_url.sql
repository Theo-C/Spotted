-- =============================================================
-- Spotted — Migration 0015 : ajoute photo_url à species_reference
-- =============================================================
-- Oubli dans 0014 : la table species_reference a besoin d'une colonne
-- photo_url pour stocker l'URL de l'image d'illustration.
--
-- Source des URLs : pas Claude.ai (il hallucine les chemins
-- Wikimedia / Wikipedia), mais l'API iNaturalist
-- (https://api.inaturalist.org/v1/taxa?q={scientific_name}&rank=species)
-- qui renvoie un default_photo.medium_url (~500 px, CC-licensed, photos
-- naturalistes de terrain). Enrichissement post-import via un petit
-- script Dart one-shot (cf. tools/enrich_inat_photos.dart).
--
-- Nullable : NULL = pas encore enrichi, l'app retombe sur le fallback
-- emoji habituel.
-- =============================================================

alter table public.species_reference
  add column if not exists photo_url text;

-- Vérification :
--   select count(*) from public.species_reference where photo_url is not null;
--   → 0 avant enrichissement.
