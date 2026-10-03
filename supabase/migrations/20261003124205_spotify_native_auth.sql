-- Version matches the migration applied to the WhoListens project.
create table public.spotify_accounts (
  spotify_id text primary key,
  user_id uuid unique references auth.users(id) on delete set null,
  refresh_handle_hash text unique,
  refresh_token text,
  updated_at timestamptz not null default now()
);

alter table public.spotify_accounts enable row level security;
revoke all on public.spotify_accounts from anon, authenticated;
grant select, insert, update, delete on public.spotify_accounts to service_role;

-- Only the service role may inspect Auth's identity and email tables during
-- the Spotify-to-Supabase session exchange.
create function public.spotify_auth_lookup(p_spotify_id text, p_email text)
returns table(spotify_user_id uuid, email_user_id uuid)
language sql
security definer
set search_path = ''
as $$
  select
    (select i.user_id from auth.identities i
     where i.provider = 'spotify' and i.provider_id = p_spotify_id limit 1),
    (select u.id from auth.users u
     where lower(u.email) = lower(p_email) limit 1);
$$;

revoke all on function public.spotify_auth_lookup(text, text) from public, anon, authenticated;
grant execute on function public.spotify_auth_lookup(text, text) to service_role;
