-- ============================================================
-- Uhr, Schritt 3
--   timer_presets:   Timer-Vorlagen des Haushalts (mitgelieferte haben feste IDs „std-…“)
--   household_night: „Gute Nacht“ von irgendeinem Gerät → Wanddisplays wechseln in die Nachtuhr
-- ============================================================

create table if not exists public.timer_presets (
  household_id uuid not null references public.households(id) on delete cascade,
  id text not null,
  name text not null,
  icon text not null default '',
  secs int not null check (secs > 0),
  position int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (household_id, id)
);
alter table public.timer_presets enable row level security;
drop policy if exists timer_presets_household on public.timer_presets;
create policy timer_presets_household on public.timer_presets for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

create table if not exists public.household_night (
  household_id uuid primary key references public.households(id) on delete cascade,
  requested_at timestamptz not null default now(),
  device text not null default ''
);
alter table public.household_night enable row level security;
drop policy if exists household_night_household on public.household_night;
create policy household_night_household on public.household_night for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'household_night') then
    alter publication supabase_realtime add table public.household_night;
  end if;
end $$;
