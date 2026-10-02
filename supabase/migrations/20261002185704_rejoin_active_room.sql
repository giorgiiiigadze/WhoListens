-- Existing members may reconnect after an app restart. New members still join
-- only waiting rooms; completed and closed rooms do not admit anyone new.
create or replace function public.join_game_room(p_code text) returns public.rooms
language plpgsql security definer set search_path = '' as $$
declare v_room public.rooms;
begin
  if auth.uid() is null or not exists (select 1 from public.profiles where id = auth.uid()) then
    raise exception 'Complete your profile before joining a room';
  end if;
  select * into v_room from public.rooms where code = upper(trim(p_code)) for update;
  if not found then raise exception 'Room not found. Check the code and try again'; end if;
  if exists (select 1 from public.room_players where room_id = v_room.id and user_id = auth.uid()) then
    if v_room.status = 'closed' then raise exception 'This room has closed'; end if;
    return v_room;
  end if;
  if v_room.status <> 'waiting' then raise exception 'This room is no longer accepting players'; end if;
  insert into public.room_players(room_id, user_id) values (v_room.id, auth.uid());
  return v_room;
end;
$$;
revoke all on function public.join_game_room(text) from public, anon;
grant execute on function public.join_game_room(text) to authenticated;
