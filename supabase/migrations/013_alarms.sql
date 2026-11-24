-- ============================================================
-- Wecker (Bucket „Uhr“). Design: docs/specs/2026-11-24-uhr-wecker-design.md
--   days          1 = Mo … 7 = So; leer = einmalig
--   shared        true = klingelt im ganzen Haushalt, false = nur auf Geräten des Besitzers
--   armed_at      seit wann der Wecker in dieser Form gilt (Einschalten/Zeit ändern) –
--                 frühere Weckzeiten zählen nicht (sonst klänge ein eben gestellter Wecker sofort)
--   dismissed_for Weckzeit, die beendet bzw. übersprungen wurde (gilt auf allen Geräten)
--   snooze_for / snooze_until  Weckzeit, die gerade schlummert, und bis wann
--   lamps, light_lead, light_stagger  Licht beim Wecker (nur mit Smart Home)
-- ============================================================

create table if not exists public.alarms (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  owner uuid not null default auth.uid() references auth.users(id) on delete cascade,
  shared boolean not null default true,
  name text not null default '',
  hour int not null check (hour between 0 and 23),
  minute int not null check (minute between 0 and 59),
  days int[] not null default '{}',
  enabled boolean not null default true,
  armed_at timestamptz not null default now(),
  snooze_min int not null default 9,
  sound text not null default 'standard',
  ramp boolean not null default true,
  lamps jsonb not null default '[]'::jsonb,
  light_lead int not null default 0,
  light_stagger boolean not null default false,
  dismissed_for timestamptz,
  snooze_for timestamptz,
  snooze_until timestamptz,
  position int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.alarms enable row level security;

drop policy if exists alarms_household on public.alarms;
create policy alarms_household on public.alarms for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

drop trigger if exists alarms_touch on public.alarms;
create trigger alarms_touch before update on public.alarms for each row execute function public.touch_updated_at();

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'alarms') then
    alter publication supabase_realtime add table public.alarms;
  end if;
end $$;

-- Welches Gerät zuletzt beendet hat (zur Fehlersuche: „hat nicht geklingelt“)
alter table public.alarms add column if not exists dismissed_by text;
