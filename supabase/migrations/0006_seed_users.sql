-- =============================================================
-- Spotted — Migration 0006 : seed profils utilisateurs
-- =============================================================
-- Insère les lignes public.users pour les 2 comptes Auth créés
-- manuellement dans Supabase Dashboard (Phase 3.A).
--
-- Les UUID référencent auth.users(id). Le FK on delete cascade
-- garantit qu'un profil est supprimé si le compte Auth l'est.
-- =============================================================

insert into public.users (id, pseudo, color_accent)
values
  ('23c6b2b1-589a-4860-aecd-8f7584bf118d', 'Théo',   '#1F3D2E'),  -- forestGreen
  ('2ad0b46c-5318-4029-9894-429cb6d0c68c', 'Axelle', '#B8624A')   -- terracotta
on conflict (id) do nothing;

-- Vérification :
--   select id, pseudo, color_accent from public.users order by pseudo;
--   → attendu : 2 lignes (Axelle, Théo)
