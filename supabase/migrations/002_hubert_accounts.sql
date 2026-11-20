-- ============================================================
-- Hubert als Smart-App: Konten, Haushalte, Bucket-Auswahl
-- Anmeldung über Supabase Auth (Mit Apple anmelden).
-- Jeder sieht nur seine eigenen Daten und die seines Haushalts (RLS).
-- ============================================================

-- Profil pro Nutzer (wird bei der ersten Anmeldung automatisch angelegt)
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text,
  interests text[] not null default '{}',
  onboarded boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

-- Welche Buckets jemand auf der Startseite hat, in welcher Reihenfolge, Größe und Einstellung
create table if not exists public.user_buckets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  bucket text not null,
  position int not null default 0,
  size text not null default 'm' check (size in ('s','m','l')),
  config jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists user_buckets_user on public.user_buckets (user_id, position);

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.user_buckets enable row level security;

-- Hilfsfunktion: Ist der angemeldete Nutzer Mitglied? (security definer verhindert Endlosschleife in RLS)
create or replace function public.is_household_member(hid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from household_members where household_id = hid and user_id = auth.uid());
$$;

-- Profile: nur das eigene
drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Haushalte: sehen, wenn Mitglied; Name ändern, wenn Mitglied. Anlegen/Beitreten nur über Funktionen unten.
drop policy if exists households_read on public.households;
create policy households_read on public.households for select to authenticated using (public.is_household_member(id));
drop policy if exists households_update on public.households;
create policy households_update on public.households for update to authenticated
  using (public.is_household_member(id)) with check (public.is_household_member(id));

-- Mitglieder: alle Mitglieder des eigenen Haushalts sehen; selbst austreten
drop policy if exists members_read on public.household_members;
create policy members_read on public.household_members for select to authenticated using (public.is_household_member(household_id));
drop policy if exists members_leave on public.household_members;
create policy members_leave on public.household_members for delete to authenticated using (user_id = auth.uid());

-- Buckets: nur die eigenen
drop policy if exists buckets_own on public.user_buckets;
create policy buckets_own on public.user_buckets for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Profil automatisch anlegen
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Einladungscode: 6 Zeichen ohne verwechselbare Zeichen (kein 0/O, 1/I)
create or replace function public.new_invite_code()
returns text language plpgsql as $$
declare chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; code text; i int;
begin
  loop
    code := '';
    for i in 1..6 loop code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from households where invite_code = code);
  end loop;
  return code;
end $$;

-- Haushalt anlegen (Ersteller wird Mitglied)
create or replace function public.create_household(p_name text)
returns public.households language plpgsql security definer set search_path = public as $$
declare h households;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  insert into households (name, invite_code, created_by)
    values (coalesce(nullif(trim(p_name), ''), 'Mein Haushalt'), new_invite_code(), auth.uid())
    returning * into h;
  insert into household_members (household_id, user_id, role) values (h.id, auth.uid(), 'owner');
  return h;
end $$;

-- Haushalt per Code beitreten
create or replace function public.join_household(p_code text)
returns public.households language plpgsql security definer set search_path = public as $$
declare h households;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  select * into h from households where invite_code = upper(trim(p_code));
  if not found then raise exception 'Code unbekannt' using errcode = 'P0002'; end if;
  insert into household_members (household_id, user_id) values (h.id, auth.uid()) on conflict do nothing;
  return h;
end $$;

-- Mein Haushalt (der zuerst beigetretene)
create or replace function public.my_household()
returns setof public.households language sql stable security definer set search_path = public as $$
  select h.* from households h join household_members m on m.household_id = h.id
  where m.user_id = auth.uid() order by m.joined_at limit 1;
$$;

revoke all on function public.create_household(text), public.join_household(text), public.my_household(),
  public.is_household_member(uuid), public.new_invite_code() from public, anon;
grant execute on function public.create_household(text), public.join_household(text), public.my_household(),
  public.is_household_member(uuid) to authenticated;

revoke execute on function public.handle_new_user(), public.new_invite_code() from authenticated;
