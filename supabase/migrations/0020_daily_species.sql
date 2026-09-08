-- =============================================================
-- Spotted — Migration 0020 : Espèce du jour
-- =============================================================
-- Une espèce est tirée aléatoirement chaque jour et par utilisateur,
-- parmi celles non-observées dans sa zone GPS courante. Si observée
-- le jour J, bonus x2 sur les points crédités.
--
-- Le tirage se fait côté client (au 1er accès Home du jour) puis est
-- persisté ici pour être stable jusqu'au lendemain — pas d'Edge Function
-- cron pour rester simple au MVP. Une ligne par (user_id, challenge_date).
-- =============================================================

create table if not exists public.daily_species (
  user_id         uuid        not null references public.users(id) on delete cascade,
  challenge_date  date        not null,
  zone_id         uuid                 references public.zones(id) on delete set null,
  species_id      uuid        not null references public.species(id) on delete restrict,
  created_at      timestamptz not null default now(),
  primary key (user_id, challenge_date)
);

comment on table public.daily_species is
  'Espèce tirée pour un user à une date donnée (bonus x2 si observée le jour J).';
comment on column public.daily_species.zone_id is
  'Zone au moment du tirage — pour info, pas de contrainte si l''user change de zone après.';

-- Index pour lookup "quelle espèce aujourd'hui" (le PK couvre déjà mais un
-- index sur species_id sert aux stats globales éventuelles).
create index if not exists idx_daily_species_species_id
  on public.daily_species (species_id);

-- -------------------------------------------------------------
-- RLS — un user ne voit et n'insère QUE ses propres tirages.
-- -------------------------------------------------------------
alter table public.daily_species enable row level security;

create policy "daily_species_select_own"
  on public.daily_species for select
  using (auth.uid() = user_id);

create policy "daily_species_insert_own"
  on public.daily_species for insert
  with check (auth.uid() = user_id);

-- Vérification :
--   select challenge_date, species_id from public.daily_species
--    where user_id = auth.uid()
--    order by challenge_date desc limit 5;
