-- ============================================================
-- Konto löschen (App-Store-Pflicht für Apps mit Konto).
-- Löscht das eigene Konto. Haushalte, in denen man das letzte Mitglied ist,
-- werden samt Küche gelöscht; sonst bleibt der Haushalt für die anderen bestehen.
-- Profil, Buckets und Mitgliedschaften verschwinden über "on delete cascade".
-- ============================================================
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Nicht angemeldet'; end if;
  delete from households h
  where exists (select 1 from household_members m where m.household_id = h.id and m.user_id = uid)
    and (select count(*) from household_members m where m.household_id = h.id) = 1;
  delete from auth.users where id = uid;
end $$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
