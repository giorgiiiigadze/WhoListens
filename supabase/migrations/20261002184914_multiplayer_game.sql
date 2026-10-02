-- Multiplayer state is mutated only by authenticated RPCs. The private answer
-- table is never exposed to the Data API. Demo tracks are explicitly temporary.
create schema if not exists game_private;

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9]{4}$'),
  host_id uuid not null references public.profiles(id),
  status text not null default 'waiting' check (status in ('waiting','playing','completed','closed')),
  current_round integer not null default 0 check (current_round >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index rooms_host_idx on public.rooms(host_id);

create table public.room_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  score integer not null default 0 check (score >= 0),
  joined_at timestamptz not null default now(),
  unique (room_id, user_id)
);
create index room_players_user_idx on public.room_players(user_id);

create table public.game_rounds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_number integer not null check (round_number > 0),
  track_name text not null,
  artist_name text not null,
  album_name text,
  album_image_url text,
  spotify_uri text,
  is_demo boolean not null default true,
  status text not null default 'pending' check (status in ('pending','voting','revealed')),
  created_at timestamptz not null default now(),
  unique (room_id, round_number)
);
create index game_rounds_room_idx on public.game_rounds(room_id, status);

create table game_private.round_answers (
  round_id uuid primary key references public.game_rounds(id) on delete cascade,
  owner_user_id uuid not null references public.profiles(id)
);

create table public.votes (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.game_rounds(id) on delete cascade,
  voter_user_id uuid not null references public.profiles(id),
  guessed_user_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (round_id, voter_user_id)
);
create index votes_round_idx on public.votes(round_id);

alter table public.rooms enable row level security;
alter table public.room_players enable row level security;
alter table public.game_rounds enable row level security;
alter table public.votes enable row level security;
alter table game_private.round_answers enable row level security;

-- No direct writes, including scores, host changes, round transitions, or votes.
grant select on public.rooms, public.room_players, public.game_rounds, public.votes to authenticated;
revoke all on public.rooms, public.room_players, public.game_rounds, public.votes from anon;
revoke insert, update, delete on public.rooms, public.room_players, public.game_rounds, public.votes from authenticated;
revoke all on schema game_private from public, anon, authenticated;
revoke all on game_private.round_answers from public, anon, authenticated;

create function game_private.is_member(p_room uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.room_players where room_id = p_room and user_id = (select auth.uid()));
$$;
revoke all on function game_private.is_member(uuid) from public, anon, authenticated;

create policy "Members read rooms" on public.rooms for select to authenticated
using (game_private.is_member(id));
create policy "Members read players" on public.room_players for select to authenticated
using (game_private.is_member(room_id));
create policy "Members read rounds" on public.game_rounds for select to authenticated
using (game_private.is_member(room_id) and status <> 'pending');
create policy "Votes visible after reveal or to voter" on public.votes for select to authenticated
using (
  voter_user_id = (select auth.uid()) or exists (
    select 1 from public.game_rounds r
    where r.id = round_id and r.status = 'revealed' and game_private.is_member(r.room_id)
  )
);

-- Public RPC entry points are security definer only because they must make
-- atomic, validated changes to otherwise immutable tables. Every function
-- checks auth.uid() and is granted exclusively to authenticated.
create function public.create_game_room() returns public.rooms
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms; v_code text; v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if auth.uid() is null or not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Complete your profile before creating a room';
  end if;
  for attempt in 1..30 loop
    v_code := '';
    for i in 1..4 loop
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars))::int + 1, 1);
    end loop;
    begin
      insert into public.rooms(code, host_id) values (v_code, auth.uid()) returning * into v_room;
      insert into public.room_players(room_id, user_id) values (v_room.id, auth.uid());
      return v_room;
    exception when unique_violation then
      -- A collision is retried; any other error escapes the function.
    end;
  end loop;
  raise exception 'Could not reserve a room code; please try again';
end;
$$;

create function public.join_game_room(p_code text) returns public.rooms
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms;
begin
  if auth.uid() is null or not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Complete your profile before joining a room';
  end if;
  select * into v_room from public.rooms where code = upper(trim(p_code)) for update;
  if not found then raise exception 'Room not found. Check the code and try again'; end if;
  if v_room.status <> 'waiting' then raise exception 'This room is no longer accepting players'; end if;
  insert into public.room_players(room_id, user_id) values (v_room.id, auth.uid())
  on conflict (room_id, user_id) do nothing;
  return v_room;
end;
$$;

create function public.leave_game_room(p_room uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms; v_new_host uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.rooms where id = p_room for update;
  if not found or not game_private.is_member(p_room) then raise exception 'Room unavailable'; end if;
  if v_room.status = 'playing' then
    -- Lock roster during a game; preserve reconnects and round consistency.
    raise exception 'Players can leave after the game finishes';
  end if;
  delete from public.room_players where room_id = p_room and user_id = auth.uid();
  if v_room.host_id = auth.uid() then
    select user_id into v_new_host from public.room_players
    where room_id = p_room order by joined_at, id limit 1;
    if v_new_host is null then
      update public.rooms set status = 'closed', updated_at = now() where id = p_room;
    else
      update public.rooms set host_id = v_new_host, updated_at = now() where id = p_room;
    end if;
  end if;
end;
$$;

create function public.start_game_room(p_room uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms; v_players uuid[]; v_owner uuid; v_round uuid; v_count int;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.rooms where id = p_room for update;
  if not found or v_room.host_id <> auth.uid() or v_room.status <> 'waiting' then
    raise exception 'Only the host can start a waiting room';
  end if;
  select array_agg(user_id order by joined_at, id) into v_players
  from public.room_players where room_id = p_room;
  v_count := coalesce(array_length(v_players, 1), 0);
  if v_count < 2 then raise exception 'At least two players are needed'; end if;
  -- Development provider: each player owns one clearly labeled demo track.
  -- Replace metadata selection here with a server-side Spotify provider.
  for i in 1..v_count loop
    v_owner := v_players[i];
    insert into public.game_rounds(room_id, round_number, track_name, artist_name,
                                  album_name, is_demo, status)
    values (p_room, i, 'Demo track ' || i, 'WhoListens demo',
            'Development round', true, case when i = 1 then 'voting' else 'pending' end)
    returning id into v_round;
    insert into game_private.round_answers(round_id, owner_user_id) values (v_round, v_owner);
  end loop;
  update public.rooms set status = 'playing', current_round = 1, updated_at = now() where id = p_room;
end;
$$;

create function public.cast_game_vote(p_round uuid, p_guess uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_round public.game_rounds; v_room public.rooms; v_owner uuid; v_required int; v_cast int;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_round from public.game_rounds where id = p_round;
  if not found then raise exception 'Round not found'; end if;
  select * into v_room from public.rooms where id = v_round.room_id for update;
  if v_room.status <> 'playing' or v_room.current_round <> v_round.round_number
      or v_round.status <> 'voting' or not game_private.is_member(v_room.id) then
    raise exception 'This round is not open for voting';
  end if;
  if not exists (select 1 from public.room_players where room_id = v_room.id and user_id = p_guess) then
    raise exception 'Choose a player in this room';
  end if;
  insert into public.votes(round_id, voter_user_id, guessed_user_id)
  values (p_round, auth.uid(), p_guess);
  update public.rooms set updated_at = now() where id = v_room.id;
  select count(*) into v_required from public.room_players where room_id = v_room.id;
  select count(*) into v_cast from public.votes where round_id = p_round;
  if v_cast = v_required then
    select owner_user_id into v_owner from game_private.round_answers where round_id = p_round;
    update public.room_players set score = score + 1 where room_id = v_room.id and user_id in (
      select voter_user_id from public.votes where round_id = p_round and guessed_user_id = v_owner
    );
    update public.game_rounds set status = 'revealed' where id = p_round;
    update public.rooms set updated_at = now() where id = v_room.id;
  end if;
end;
$$;

create function public.game_vote_count(p_round uuid) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare v_count integer;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select count(*) into v_count from public.votes v
  join public.game_rounds r on r.id = v.round_id
  where r.id = p_round and game_private.is_member(r.room_id);
  return v_count;
end;
$$;

create function public.revealed_round_owner(p_round uuid) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select a.owner_user_id into v_owner
  from game_private.round_answers a join public.game_rounds r on r.id = a.round_id
  where r.id = p_round and r.status = 'revealed' and game_private.is_member(r.room_id);
  return v_owner;
end;
$$;

create function public.advance_game_room(p_room uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms; v_next int;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.rooms where id = p_room for update;
  if not found or v_room.host_id <> auth.uid() or v_room.status <> 'playing' then
    raise exception 'Only the host can advance the game';
  end if;
  if not exists (select 1 from public.game_rounds where room_id = p_room
                 and round_number = v_room.current_round and status = 'revealed') then
    raise exception 'Wait for all players to vote';
  end if;
  v_next := v_room.current_round + 1;
  if exists (select 1 from public.game_rounds where room_id = p_room and round_number = v_next) then
    update public.game_rounds set status = 'voting' where room_id = p_room and round_number = v_next;
    update public.rooms set current_round = v_next, updated_at = now() where id = p_room;
  else
    update public.rooms set status = 'completed', updated_at = now() where id = p_room;
  end if;
end;
$$;

create function public.play_game_again(p_room uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.rooms where id = p_room for update;
  if not found or v_room.host_id <> auth.uid() or v_room.status <> 'completed' then
    raise exception 'Only the host can restart a completed game';
  end if;
  delete from public.game_rounds where room_id = p_room;
  update public.room_players set score = 0 where room_id = p_room;
  update public.rooms set status = 'waiting', current_round = 0, updated_at = now() where id = p_room;
end;
$$;

revoke all on function public.create_game_room(), public.join_game_room(text),
  public.leave_game_room(uuid), public.start_game_room(uuid),
  public.cast_game_vote(uuid,uuid), public.revealed_round_owner(uuid),
  public.advance_game_room(uuid), public.play_game_again(uuid),
  public.game_vote_count(uuid) from public, anon;
grant execute on function public.create_game_room(), public.join_game_room(text),
  public.leave_game_room(uuid), public.start_game_room(uuid),
  public.cast_game_vote(uuid,uuid), public.revealed_round_owner(uuid),
  public.advance_game_room(uuid), public.play_game_again(uuid),
  public.game_vote_count(uuid) to authenticated;

alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.room_players;
alter publication supabase_realtime add table public.game_rounds;
alter publication supabase_realtime add table public.votes;
