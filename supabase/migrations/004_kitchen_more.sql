-- ============================================================
-- Küche, Runde 2:
--   kitchen_cooked    jedes Kochen einzeln (für die Koch-Statistik)
--   kitchen_recipes   eigene Rezepte des Haushalts (auch per Link importiert)
--   kitchen_follows   Familien-Kochbuch: Haushalt X liest die Rezepte von Haushalt Y
--   households.cookbook_code  Code, mit dem andere dem Kochbuch folgen
--   kitchen_tokens    Schlüssel für den Siri-Kurzbefehl (nur als sha256-Hash)
-- ============================================================

create table if not exists public.kitchen_cooked (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  recipe_id text not null,
  cooked_at timestamptz not null default now()
);
create index if not exists kitchen_cooked_household on public.kitchen_cooked (household_id, cooked_at desc);

create table if not exists public.kitchen_recipes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists kitchen_recipes_household on public.kitchen_recipes (household_id);

create table if not exists public.kitchen_follows (
  household_id uuid not null references public.households(id) on delete cascade,
  source_id uuid not null references public.households(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (household_id, source_id),
  check (household_id <> source_id)
);

alter table public.households add column if not exists cookbook_code text unique;

create table if not exists public.kitchen_tokens (
  token_hash text primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.kitchen_cooked enable row level security;
alter table public.kitchen_recipes enable row level security;
alter table public.kitchen_follows enable row level security;
alter table public.kitchen_tokens enable row level security;

drop policy if exists kitchen_cooked_household on public.kitchen_cooked;
create policy kitchen_cooked_household on public.kitchen_cooked for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

-- Eigene Rezepte: Mitglieder dürfen alles; wer einem Kochbuch folgt, darf lesen
drop policy if exists kitchen_recipes_own on public.kitchen_recipes;
create policy kitchen_recipes_own on public.kitchen_recipes for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
drop policy if exists kitchen_recipes_followed on public.kitchen_recipes;
create policy kitchen_recipes_followed on public.kitchen_recipes for select to authenticated
  using (exists (select 1 from public.kitchen_follows f
                 where f.source_id = kitchen_recipes.household_id and public.is_household_member(f.household_id)));

drop policy if exists kitchen_follows_own on public.kitchen_follows;
create policy kitchen_follows_own on public.kitchen_follows for select to authenticated
  using (public.is_household_member(household_id));
drop policy if exists kitchen_follows_leave on public.kitchen_follows;
create policy kitchen_follows_leave on public.kitchen_follows for delete to authenticated
  using (public.is_household_member(household_id));

drop policy if exists kitchen_tokens_own on public.kitchen_tokens;
create policy kitchen_tokens_own on public.kitchen_tokens for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

drop trigger if exists kitchen_recipes_touch on public.kitchen_recipes;
create trigger kitchen_recipes_touch before update on public.kitchen_recipes for each row execute function public.touch_updated_at();

-- Kochbuch-Code des eigenen Haushalts (wird beim ersten Mal angelegt)
create or replace function public.my_cookbook_code(p_household uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if not public.is_household_member(p_household) then raise exception 'Kein Mitglied'; end if;
  select cookbook_code into c from households where id = p_household;
  if c is null then
    loop
      c := 'KB-' || upper(substr(md5(random()::text), 1, 6));
      exit when not exists (select 1 from households where cookbook_code = c);
    end loop;
    update households set cookbook_code = c where id = p_household;
  end if;
  return c;
end $$;

-- Einem Kochbuch folgen; gibt den Namen des anderen Haushalts zurück
create or replace function public.follow_cookbook(p_household uuid, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare src households%rowtype;
begin
  if not public.is_household_member(p_household) then raise exception 'Kein Mitglied'; end if;
  select * into src from households where cookbook_code = upper(trim(p_code));
  if not found then raise exception 'Unbekannter Code'; end if;
  if src.id = p_household then raise exception 'Das ist euer eigenes Kochbuch'; end if;
  insert into kitchen_follows (household_id, source_id) values (p_household, src.id) on conflict do nothing;
  return src.name;
end $$;

-- Namen der Haushalte, denen man folgt (die Tabelle households selbst ist nur für Mitglieder lesbar)
create or replace function public.followed_cookbooks(p_household uuid) returns table (source_id uuid, name text)
language sql stable security definer set search_path = public as $$
  select f.source_id, h.name from kitchen_follows f join households h on h.id = f.source_id
  where f.household_id = p_household and public.is_household_member(p_household);
$$;

revoke execute on function public.my_cookbook_code(uuid), public.follow_cookbook(uuid, text),
  public.followed_cookbooks(uuid) from public, anon;
grant execute on function public.my_cookbook_code(uuid), public.follow_cookbook(uuid, text),
  public.followed_cookbooks(uuid) to authenticated;
