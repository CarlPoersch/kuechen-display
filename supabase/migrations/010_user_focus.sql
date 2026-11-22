-- Fokus-Timer: eine Zeile je Konto, damit ein laufender Fokus auf allen eigenen Geräten
-- sichtbar ist und überall pausiert/beendet werden kann (Realtime). Nur der Besitzer sieht sie.
create table if not exists public.user_focus (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_focus enable row level security;
drop policy if exists "eigener Fokus" on public.user_focus;
create policy "eigener Fokus" on public.user_focus for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
alter publication supabase_realtime add table public.user_focus;
