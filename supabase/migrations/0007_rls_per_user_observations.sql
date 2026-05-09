-- =============================================================
-- Spotted — Migration 0007 : RLS observations per-user writes
-- =============================================================
-- Évolution du modèle "compte partagé" → "2 comptes dissociés".
-- Théo et Axelle ont désormais chacun leur compte auth Supabase.
--
-- Changement de logique :
--   - SELECT : INCHANGÉ (true) — chacun voit toutes les obs (carnet partagé).
--   - INSERT/UPDATE/DELETE : on durcit. Chacun ne crée/modifie/supprime
--     que SES PROPRES obs (user_id = auth.uid()).
--
-- Justification : l'ancien modèle permettait à n'importe lequel des deux
-- de modifier une obs de l'autre. Avec 2 comptes dissociés, on aligne le
-- droit d'écriture sur l'identité auth — chacun reste maître de son carnet.
-- Le partage en lecture est conservé (esprit "couple naturaliste").
-- =============================================================

-- Drop des policies INSERT/UPDATE/DELETE actuelles sur observations
drop policy if exists "observations_insert" on public.observations;
drop policy if exists "observations_update" on public.observations;
drop policy if exists "observations_delete" on public.observations;

-- Recréation avec contrainte sur auth.uid()

-- INSERT : on ne peut créer qu'une obs avec son propre user_id.
create policy "observations_insert" on public.observations
  for insert to authenticated
  with check (user_id = auth.uid());

-- UPDATE : on ne peut modifier qu'une obs dont on est propriétaire.
-- Le `with check` empêche aussi de transférer une obs à un autre user.
create policy "observations_update" on public.observations
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- DELETE : on ne peut supprimer que ses propres obs.
create policy "observations_delete" on public.observations
  for delete to authenticated
  using (user_id = auth.uid());

-- =============================================================
-- Vérification post-migration
-- =============================================================
-- select policyname, cmd, qual, with_check
-- from pg_policies
-- where schemaname = 'public' and tablename = 'observations'
-- order by cmd;
--
-- Résultat attendu :
--   observations_select  | SELECT | true                | -
--   observations_insert  | INSERT | -                   | (user_id = auth.uid())
--   observations_update  | UPDATE | (user_id = ...)     | (user_id = auth.uid())
--   observations_delete  | DELETE | (user_id = auth..)  | -
-- =============================================================
