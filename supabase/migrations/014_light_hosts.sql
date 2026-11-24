-- ============================================================
-- Licht für Wecker und Timer (Uhr, Schritt 2)
--   light_hosts: Geräte mit offenem Hubert, die gerade Lampen im WLAN erreichen.
--   Geschaltet wird nur vom „Lichtgerät“: Wanddisplays zuerst, dann das am längsten laufende.
--   kitchen_timers.light_action / lamps: „Am Ende: Lampen an/aus“
-- ============================================================

create table if not exists public.light_hosts (
  household_id uuid not null references public.households(id) on delete cascade,
  device text not null,
  name text not null default '',
  wall boolean not null default false,
  started_at timestamptz not null default now(),
  seen_at timestamptz not null default now(),
  primary key (household_id, device)
);
alter table public.light_hosts enable row level security;
drop policy if exists light_hosts_household on public.light_hosts;
create policy light_hosts_household on public.light_hosts for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

alter table public.kitchen_timers add column if not exists light_action text;
alter table public.kitchen_timers add column if not exists lamps jsonb not null default '[]'::jsonb;
