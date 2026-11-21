-- ============================================================
-- Live-Abgleich im Haushalt: laufende Timer und das Rezept, das gerade gekocht wird.
-- Alle Geräte des Haushalts sehen dasselbe (iPhone, Küchen-iPad, Handy der Partnerin).
--   kitchen_timers   ein Eintrag pro laufendem/klingelndem Timer; „OK“ auf einem Gerät löscht ihn überall
--   kitchen_cooking  höchstens ein Rezept pro Haushalt, inkl. aktuellem Schritt
-- Änderungen kommen per Supabase Realtime sofort auf die anderen Geräte.
-- ============================================================

create table if not exists public.kitchen_timers (
  id uuid primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null,
  total_secs double precision not null,
  end_at timestamptz not null,
  paused_left double precision,
  source text,
  icon text,
  device text,
  created_at timestamptz not null default now()
);
create index if not exists kitchen_timers_household on public.kitchen_timers (household_id);

create table if not exists public.kitchen_cooking (
  household_id uuid primary key references public.households(id) on delete cascade,
  recipe_id text not null,
  portions int not null default 2 check (portions between 1 and 20),
  page int not null default 0,
  device text,
  updated_at timestamptz not null default now()
);

alter table public.kitchen_timers enable row level security;
alter table public.kitchen_cooking enable row level security;

drop policy if exists kitchen_timers_household on public.kitchen_timers;
create policy kitchen_timers_household on public.kitchen_timers for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
drop policy if exists kitchen_cooking_household on public.kitchen_cooking;
create policy kitchen_cooking_household on public.kitchen_cooking for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

-- Realtime: Änderungen an diese Tabellen (und Einkauf/Plan) an die Geräte melden
do $$
declare t text;
begin
  foreach t in array array['kitchen_timers', 'kitchen_cooking', 'kitchen_items', 'kitchen_plan'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
