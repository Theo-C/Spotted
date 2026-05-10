-- =============================================================
-- Spotted — Migration 0013 : bucket Storage 'species'
-- =============================================================
-- Crée un bucket public 'species' pour stocker une photo
-- d'illustration par espèce du catalogue. Pattern identique au bucket
-- 'observations' (cf. 0007_storage_policies.sql) : public en lecture,
-- INSERT/UPDATE/DELETE pour les authentifiés (Théo + Axelle).
--
-- Les paths des fichiers suivent la convention `{authUserId}/{ts}.jpg`
-- pour garder la même structure que les obs (traçable au uploader).
-- =============================================================

-- Création du bucket s'il n'existe pas (idempotent).
insert into storage.buckets (id, name, public)
values ('species', 'species', true)
on conflict (id) do nothing;

-- Policies INSERT/UPDATE/DELETE pour les utilisateurs authentifiés.
-- SELECT n'a pas besoin de policy : le bucket est public.
create policy "species_storage_insert"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'species');

create policy "species_storage_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'species')
with check (bucket_id = 'species');

create policy "species_storage_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'species');

-- Vérification :
--   select policyname, cmd from pg_policies
--   where schemaname = 'storage' and tablename = 'objects'
--     and policyname like 'species_storage_%';
--   → 3 nouvelles policies.
--
--   select id, public from storage.buckets where id = 'species';
--   → species | true
