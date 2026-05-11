-- =============================================================
-- Spotted — Migration 0016 : recherche species_reference insensible
-- à la casse ET aux accents
-- =============================================================
-- Le ilike PostgreSQL est case-insensitive mais accent-sensitive :
-- "ecureuil" ne match pas "Écureuil". Pour un autocomplete naturaliste
-- en français, on veut les deux.
--
-- Solution : extension `unaccent` (intégrée à Postgres, fournie par
-- Supabase) qui supprime les diacritiques. On l'utilise dans une RPC
-- dédiée — PostgREST ne sait pas appeler des fonctions dans un filtre
-- `.or()`, donc on passe par rpc('search_species_reference', ...) côté
-- client.
-- =============================================================

-- Active l'extension unaccent (idempotent).
create extension if not exists unaccent;

-- Fonction de recherche : ilike sur common_name OU scientific_name,
-- avec unaccent appliqué des deux côtés (colonne ET requête).
-- stable + sql pur → optimisable / cacheable par PG.
create or replace function public.search_species_reference(q text)
returns setof public.species_reference
language sql stable
as $$
  select *
  from public.species_reference
  where unaccent(common_name) ilike '%' || unaccent(q) || '%'
     or unaccent(scientific_name) ilike '%' || unaccent(q) || '%'
  order by common_name asc
  limit 10;
$$;

-- Les users authenticated peuvent appeler cette fonction (lecture seule
-- sur une table déjà accessible en SELECT pour eux).
grant execute on function public.search_species_reference(text) to authenticated;

-- =============================================================
-- Vérification (lance après la migration) :
--   select * from public.search_species_reference('ecureuil');
--   → doit retourner "Écureuil roux" malgré l'absence d'accent dans la requête.
--
--   select * from public.search_species_reference('MESANGE');
--   → doit retourner toutes les "Mésange*" (insensible à la casse).
-- =============================================================
