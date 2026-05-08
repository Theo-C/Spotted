-- =============================================================
-- Spotted — Migration 0007 : Storage policies (bucket 'observations')
-- =============================================================
-- Le bucket 'observations' est public (lecture libre via URL signée),
-- donc on n'a pas besoin de policy SELECT — Supabase l'ouvre par défaut.
--
-- En revanche, INSERT/UPDATE/DELETE doivent être autorisés pour les
-- utilisateurs authentifiés (Théo + Axelle), sinon l'upload échoue
-- avec une "row level security" exception.
-- =============================================================

create policy "observations_storage_insert"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'observations');

create policy "observations_storage_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'observations')
with check (bucket_id = 'observations');

create policy "observations_storage_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'observations');

-- Vérification :
--   select policyname, cmd from pg_policies
--   where schemaname = 'storage' and tablename = 'objects';
--   → 3 nouvelles policies "observations_storage_*".
