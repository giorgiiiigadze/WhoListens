-- Hide demo owners by choosing a server-side random player order.
create or replace function public.start_game_room(p_room uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms; v_players uuid[]; v_owner uuid; v_round uuid; v_count int;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.rooms where id = p_room for update;
  if not found or v_room.host_id <> auth.uid() or v_room.status <> 'waiting' then
    raise exception 'Only the host can start a waiting room';
  end if;
  select array_agg(user_id order by random()) into v_players
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
