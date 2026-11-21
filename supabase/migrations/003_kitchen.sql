-- ============================================================
-- Küche für die native App: gemeinsam im Haushalt.
--   kitchen_items  Einkaufsliste (kind = 'shop') und Vorrat (kind = 'pantry')
--   kitchen_plan   Wochenplan: Rezept an einem Tag, mit Portionen
--   kitchen_meta   je Rezept: Bewertung, Notiz, wie oft/zuletzt gekocht
-- Rezepte selbst bleiben die JSON-Dateien im Repo (GitHub Pages).
-- Zugriff: nur Mitglieder des Haushalts (is_household_member).
-- ============================================================

create table if not exists public.kitchen_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  kind text not null check (kind in ('shop', 'pantry')),
  name text not null,
  amount text not null default '',
  place text not null default '',
  mhd date,
  done boolean not null default false,
  recipe text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists kitchen_items_household on public.kitchen_items (household_id, kind);

create table if not exists public.kitchen_plan (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  day date not null,
  recipe_id text not null,
  portions int not null default 2 check (portions between 1 and 20),
  created_at timestamptz not null default now()
);
create index if not exists kitchen_plan_household on public.kitchen_plan (household_id, day);

create table if not exists public.kitchen_meta (
  household_id uuid not null references public.households(id) on delete cascade,
  recipe_id text not null,
  rating smallint check (rating between 1 and 5),
  note text not null default '',
  cooked_count int not null default 0,
  last_cooked timestamptz,
  updated_at timestamptz not null default now(),
  primary key (household_id, recipe_id)
);

alter table public.kitchen_items enable row level security;
alter table public.kitchen_plan enable row level security;
alter table public.kitchen_meta enable row level security;

drop policy if exists kitchen_items_household on public.kitchen_items;
create policy kitchen_items_household on public.kitchen_items for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
drop policy if exists kitchen_plan_household on public.kitchen_plan;
create policy kitchen_plan_household on public.kitchen_plan for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
drop policy if exists kitchen_meta_household on public.kitchen_meta;
create policy kitchen_meta_household on public.kitchen_meta for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

-- updated_at automatisch setzen (für den Abgleich zwischen Geräten)
create or replace function public.touch_updated_at() returns trigger language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists kitchen_items_touch on public.kitchen_items;
create trigger kitchen_items_touch before update on public.kitchen_items for each row execute function public.touch_updated_at();
drop trigger if exists kitchen_meta_touch on public.kitchen_meta;
create trigger kitchen_meta_touch before update on public.kitchen_meta for each row execute function public.touch_updated_at();
