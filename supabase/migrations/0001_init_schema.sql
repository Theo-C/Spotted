-- =============================================================
-- Spotted — Migration 0001 : schéma initial MVP
-- =============================================================
-- Tables : users, countries, zones, categories, species,
--          species_zones, observations
-- Trigger : is_first_for_user calculé serveur (anti-triche client)
-- À exécuter dans le SQL Editor Supabase.
-- =============================================================

-- pgcrypto pour gen_random_uuid() — déjà actif sur Supabase, on s'assure
create extension if not exists pgcrypto;

-- -------------------------------------------------------------
-- Enums
-- -------------------------------------------------------------
create type rarity as enum ('common', 'rare', 'epic', 'legendary');
create type zone_type as enum ('country', 'region', 'department', 'park', 'custom');

-- -------------------------------------------------------------
-- Users (extension de auth.users)
-- -------------------------------------------------------------
create table public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  pseudo      text not null,
  color_accent text not null default '#1F3D2E',  -- forestGreen
  created_at  timestamptz not null default now()
);

comment on table public.users is 'Profil utilisateur — extension de auth.users (1 ligne par utilisateur authentifié)';

-- -------------------------------------------------------------
-- Countries
-- -------------------------------------------------------------
create table public.countries (
  id        uuid primary key default gen_random_uuid(),
  name      text not null,
  iso_code  char(2) not null unique
);

-- -------------------------------------------------------------
-- Zones (territoires curés : France/Oise au MVP)
-- -------------------------------------------------------------
create table public.zones (
  id           uuid primary key default gen_random_uuid(),
  country_id   uuid not null references public.countries(id) on delete restrict,
  name         text not null,
  short_code   text,
  type         zone_type not null default 'department',
  geojson_url  text
);

create index idx_zones_country on public.zones(country_id);

-- -------------------------------------------------------------
-- Categories (Oiseaux, Mammifères, Reptiles, Chiroptères au MVP)
-- -------------------------------------------------------------
create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  icon        text not null,        -- nom d'icône Material (ex: 'flutter_dash')
  color       text not null,        -- hex (ex: '#1F3D2E')
  sort_order  integer not null default 0
);

-- -------------------------------------------------------------
-- Species
-- -------------------------------------------------------------
create table public.species (
  id                  uuid primary key default gen_random_uuid(),
  common_name         text not null,
  scientific_name     text not null,
  category_id         uuid not null references public.categories(id) on delete restrict,
  description         text,
  photo_url           text,
  created_by_user_id  uuid references public.users(id) on delete set null,
  created_at          timestamptz not null default now()
);

create unique index idx_species_scientific_name on public.species(scientific_name);
create index idx_species_category on public.species(category_id);

-- -------------------------------------------------------------
-- Species × Zone (avec rareté locale)
-- -------------------------------------------------------------
create table public.species_zones (
  species_id  uuid not null references public.species(id) on delete cascade,
  zone_id     uuid not null references public.zones(id) on delete cascade,
  rarity      rarity not null,
  primary key (species_id, zone_id)
);

create index idx_species_zones_zone on public.species_zones(zone_id);

-- -------------------------------------------------------------
-- Observations
-- -------------------------------------------------------------
create table public.observations (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.users(id) on delete cascade,
  species_id          uuid not null references public.species(id) on delete restrict,
  zone_id             uuid references public.zones(id) on delete set null,  -- null si hors zones curées
  observed_at         timestamptz not null,
  latitude            double precision not null,
  longitude           double precision not null,
  photo_url           text,
  photo_exif_data     jsonb,
  is_first_for_user   boolean not null default false,  -- toujours recalculé par le trigger
  points_earned       integer not null,                 -- figé à l'insert (calcul côté client)
  created_at          timestamptz not null default now()
);

create index idx_observations_user on public.observations(user_id);
create index idx_observations_species on public.observations(species_id);
create index idx_observations_user_species on public.observations(user_id, species_id);

-- -------------------------------------------------------------
-- Trigger : is_first_for_user calculé serveur (anti-triche client)
-- -------------------------------------------------------------
-- À chaque INSERT dans observations, on écrase la valeur envoyée par le client
-- en testant s'il existe déjà une obs (user_id, species_id) en base.
create or replace function public.set_is_first_for_user()
returns trigger
language plpgsql
as $$
begin
  new.is_first_for_user := not exists (
    select 1
    from public.observations
    where user_id = new.user_id
      and species_id = new.species_id
  );
  return new;
end;
$$;

create trigger trg_observations_is_first
before insert on public.observations
for each row
execute function public.set_is_first_for_user();

-- =============================================================
-- Vérification : la requête suivante doit retourner 7 lignes
-- =============================================================
-- select table_name from information_schema.tables
-- where table_schema = 'public'
-- order by table_name;
