-- Zwischenspeicher für Deals (mydealz-Feeds), damit auch ältere Treffer (bis 7 Tage) erhalten bleiben.
-- Nur die Server-Funktion „deals“ (Service-Rolle) liest und schreibt – daher RLS ohne Policies.
create table if not exists public.deal_cache (
  id text primary key,
  title text not null,
  merchant text,
  price numeric,
  price_text text,
  temp int,
  cat text,
  img text,
  url text not null,
  snippet text,
  pub timestamptz not null,
  seen timestamptz not null default now()
);
create index if not exists deal_cache_pub on public.deal_cache (pub desc);
alter table public.deal_cache enable row level security;
