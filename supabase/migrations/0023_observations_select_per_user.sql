-- =============================================================
-- Spotted — Migration 0023 : RLS SELECT observations par user
-- =============================================================
-- Contexte : avant ouverture au public, on supprime le dernier vestige
-- du "carnet partagé Théo/Axelle" — la policy SELECT était encore
-- `using (true)` (héritage des migrations 0002 + 0007 qui n'avaient
-- durci que INSERT/UPDATE/DELETE).
--
-- Après cette migration, chaque user ne voit QUE ses propres observations
-- côté serveur. Les filtres côté client (`myObs.where(...)`) deviennent
-- redondants mais restent en place en defense-in-depth.
--
-- Impact utilisateurs :
--   - Home > "Dernières observations" : ne voit que les siennes ✅ déjà
--   - Carnet géo : ne voit que ses points sur la carte ← change
--   - Fiche espèce > "Mes observations" : inchangé ✅
--   - Le filtre observateur ("qui a observé") sur la Carte devient
--     obsolète — retiré dans le même sprint côté UI.
--
-- Rétrocompat teams (V2) : quand on ajoutera les équipes, cette policy
-- évoluera pour permettre aussi les obs des membres de MON équipe :
--   using (
--     auth.uid() = user_id
--     OR user_id IN (select member_id from team_members
--                     where team_id in (select team_id from team_members
--                                        where member_id = auth.uid()))
--   )
-- =============================================================

drop policy if exists "observations_select" on public.observations;

create policy "observations_select"
  on public.observations for select
  using (auth.uid() = user_id);

comment on policy "observations_select" on public.observations is
  'Chacun ne voit que ses propres observations. Assouplir quand équipes ajoutées.';

-- Vérification (connecté en tant qu'user X) :
--   select count(*) from public.observations where user_id = auth.uid();
--   select count(*) from public.observations;
-- Les 2 doivent donner le même nombre.
