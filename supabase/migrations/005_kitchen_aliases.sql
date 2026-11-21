-- Gelernte Namen für Kassenzettel-Zeilen und Barcodes ("G&G AVOCADOS" → "Avocados"), je Haushalt
create table if not exists public.kitchen_aliases (
  household_id uuid not null references public.households(id) on delete cascade,
  key text not null,
  name text not null,
  updated_at timestamptz not null default now(),
  primary key (household_id, key)
);
alter table public.kitchen_aliases enable row level security;
drop policy if exists kitchen_aliases_household on public.kitchen_aliases;
create policy kitchen_aliases_household on public.kitchen_aliases for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
