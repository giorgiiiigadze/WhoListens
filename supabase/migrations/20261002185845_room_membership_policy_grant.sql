-- RLS evaluates this narrow membership predicate as the caller. It exposes
-- only whether the signed-in user belongs to a room, and never exposes answers.
grant usage on schema game_private to authenticated;
grant execute on function game_private.is_member(uuid) to authenticated;
