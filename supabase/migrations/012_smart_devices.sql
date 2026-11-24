-- ============================================================
-- Smart Home: Tuya-Steckdosen des Haushalts (lokal im WLAN geschaltet).
--   id         Tuya-Geräte-ID
--   local_key  lokaler Schlüssel (nur im eigenen WLAN nützlich; nur der Haushalt sieht ihn)
--   version    erkannte Protokollversion ('3.3', '3.3d', '3.4', '3.5'; leer = noch unbekannt)
--   ip         zuletzt gefundene Adresse im WLAN
--   outlets    schaltbare Ausgänge: [{"dp": 1, "name": "Stehlampe"}]
-- Die Tuya-Zugangsdaten (Access ID/Secret) liegen NICHT hier, nur im Schlüsselbund.
-- ============================================================

create table if not exists public.smart_devices (
  household_id uuid not null references public.households(id) on delete cascade,
  id text not null,
  name text not null,
  local_key text not null,
  category text not null default '',
  version text not null default '',
  ip text not null default '',
  outlets jsonb not null default '[]'::jsonb,
  position int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (household_id, id)
);

alter table public.smart_devices enable row level security;

drop policy if exists smart_devices_household on public.smart_devices;
create policy smart_devices_household on public.smart_devices for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

drop trigger if exists smart_devices_touch on public.smart_devices;
create trigger smart_devices_touch before update on public.smart_devices for each row execute function public.touch_updated_at();
