-- =============================================================
-- Spotted — Migration 0014 : table `species_reference`
-- =============================================================
-- Banque de référence pré-générée (description + tips + rareté indicative)
-- pour les espèces de France métropolitaine, sur les 4 catégories du MVP
-- (birds, mammals, reptiles, bats).
--
-- Distincte de `species` : `species` ne contient QUE les espèces que les
-- utilisateurs ont ajoutées à leur catalogue curé. `species_reference`
-- contient le vivier complet, utilisé pour pré-remplir le formulaire
-- d'ajout d'une nouvelle espèce (description, tips, rareté suggérée).
--
-- Workflow d'alimentation : généré en batchs via Claude.ai (plan Max,
-- coût 0), importé en SQL via `jsonb_to_recordset` (cf. template d'import
-- dans docs ou chat). On commence par les ~250 oiseaux puis on étendra.
--
-- Lecture seule pour les users — pas de policy INSERT/UPDATE/DELETE
-- côté authenticated. Les imports passent par service_role (SQL admin).
-- =============================================================

create table if not exists public.species_reference (
  scientific_name text primary key,
  common_name     text not null,
  category_key    text not null check (
    category_key in ('birds', 'mammals', 'reptiles', 'bats')
  ),
  rarity_hint     text check (
    rarity_hint in ('common', 'rare', 'epic', 'legendary')
  ),
  description     text not null,
  tips            text not null,
  created_at      timestamptz not null default now()
);

-- Index secondaire pour la recherche par nom commun (autocomplete éventuel).
create index if not exists species_reference_common_name_idx
  on public.species_reference (common_name);

-- RLS : tous les authentifiés peuvent LIRE, personne ne peut écrire
-- (les imports se font en SQL admin).
alter table public.species_reference enable row level security;

-- Drop avant create pour rendre la migration idempotente — sinon une
-- ré-exécution accidentelle plante avec "policy already exists" (42710).
drop policy if exists "species_reference_select" on public.species_reference;
create policy "species_reference_select" on public.species_reference
  for select to authenticated using (true);

-- Vérification :
--   select count(*) from public.species_reference;
--   → 0 au départ, à remplir par les batchs claude.ai.
