-- API-Schlüssel für Edge Functions liegen verschlüsselt im Supabase Vault
-- (Name mit Präfix app_, z. B. app_tmdb_key). Der Wert steht NICHT im Repo;
-- angelegt per: select vault.create_secret('<wert>', 'app_tmdb_key', '…');
-- Lesen darf nur service_role (also nur die Edge Functions), nicht App oder Web.
create or replace function public.app_secret(p_name text)
returns text
language sql
security definer
set search_path = ''
as $$
  select decrypted_secret from vault.decrypted_secrets
  where name = p_name and p_name like 'app\_%'
  limit 1
$$;
revoke all on function public.app_secret(text) from public, anon, authenticated;
grant execute on function public.app_secret(text) to service_role;
