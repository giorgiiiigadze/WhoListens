-- Only the authenticated friends Edge Function may read or change these rows.
-- Profiles remain private; the function returns only a minimal search result.
create table public.friend_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friend_connections_not_self check (requester_id <> addressee_id)
);

create unique index friend_connections_unique_pair
  on public.friend_connections (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index friend_connections_requester_idx on public.friend_connections(requester_id);
create index friend_connections_addressee_idx on public.friend_connections(addressee_id);

alter table public.friend_connections enable row level security;
revoke all on public.friend_connections from anon, authenticated;
grant select, insert, update, delete on public.friend_connections to service_role;
