-- ============================================================
-- Gemeinsamer Speicher für das Küchen-Display
--
-- Eine Tabelle mit Schlüssel/Wert-Einträgen (Einkaufsliste, Vorrat,
-- Wochenplan, Gekocht). Zugriff NUR über die Funktion kueche_sync,
-- die den Haushalts-Schlüssel prüft. Direkter Tabellenzugriff ist
-- durch Row Level Security ohne Policies gesperrt.
-- ============================================================

create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

create table public.kueche_store (
  key        text primary key,
  entry      jsonb       not null,          -- {"v": ..., "t": ...} oder {"d": 1, "t": ...}
  t          bigint      not null,          -- Zeitstempel des Geräts (ms) -> "neuer gewinnt"
  updated_at timestamptz not null default clock_timestamp()  -- Server-Zeit -> "was ist neu?"
);
create index kueche_store_updated_at on public.kueche_store (updated_at);
alter table public.kueche_store enable row level security;  -- keine Policies = kein Direktzugriff

-- Nur der Hash des Haushalts-Schlüssels wird gespeichert, nie der Schlüssel selbst
create table private.kueche_secret (
  id       int primary key default 1 check (id = 1),
  key_hash text not null
);

-- Stimmt der Schlüssel?
create or replace function public.kueche_check(p_key text)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from private.kueche_secret
    where key_hash = encode(extensions.digest(coalesce(p_key, ''), 'sha256'), 'hex')
  );
$$;

-- Änderungen übernehmen und alles zurückgeben, was seit p_since neu ist
create or replace function public.kueche_sync(p_key text, p_changes jsonb, p_since timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  k text;
  e jsonb;
  v_now timestamptz := clock_timestamp();
  result jsonb;
begin
  if not public.kueche_check(p_key) then
    raise exception 'Falscher Haushalts-Schluessel' using errcode = '28000';
  end if;

  for k, e in select * from jsonb_each(coalesce(p_changes, '{}'::jsonb)) loop
    if jsonb_typeof(e) = 'object' and e ? 't' then
      insert into public.kueche_store (key, entry, t, updated_at)
      values (k, e, (e->>'t')::bigint, clock_timestamp())
      on conflict (key) do update
        set entry = excluded.entry, t = excluded.t, updated_at = clock_timestamp()
        where public.kueche_store.t <= excluded.t;   -- neuerer Zeitstempel gewinnt
    end if;
  end loop;

  -- 5 s Überlappung: fängt Einträge gleichzeitig laufender Abgleiche sicher mit ab
  select coalesce(jsonb_object_agg(s.key, s.entry), '{}'::jsonb)
    into result
    from public.kueche_store s
   where p_since is null or s.updated_at > p_since - interval '5 seconds';

  return jsonb_build_object('data', result, 'now', v_now);
end;
$$;

revoke all on function public.kueche_check(text) from public;
revoke all on function public.kueche_sync(text, jsonb, timestamptz) from public;
-- kueche_check nur für die Edge Function (service_role), nicht für den Browser
grant execute on function public.kueche_check(text) to service_role;
grant execute on function public.kueche_sync(text, jsonb, timestamptz) to anon, authenticated;
