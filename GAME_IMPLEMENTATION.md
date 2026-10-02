# Multiplayer game implementation

The existing Spotify OAuth and playlist display remain unchanged. The game uses the existing Supabase client and `profiles` authentication identity. Database migrations in `supabase/migrations` are deployed to the configured project.

## Room and round rules

- A room code is four characters; the database unique constraint prevents collisions. Only the host can start, advance, or restart a match.
- Joining a waiting room adds one membership. An existing member can rejoin an active room after relaunch using the saved code. A new player cannot join an active or completed room.
- A lobby host who leaves transfers ownership to the earliest remaining player, or closes an empty room.
- Closing the app does not delete membership. This preserves temporary reconnects. The active roster is locked during a match; the current backend rejects a leave request until the match completes. There is no timeout or forfeiture policy yet, so a disconnected player can leave a round waiting indefinitely.
- The database prepares one round per player. The answer is held in `game_private.round_answers`, while `game_rounds` exposes only track display data. Demo ownership order is randomized on the server.
- Votes are immutable and unique per voter and round. The final vote atomically awards one point per correct answer and reveals the round. Only the host can advance.
- Realtime subscriptions are scoped to the room ID and removed when the room screen disappears. A room update after each vote triggers a fresh vote count without polling.

## Track provider boundary

`start_game_room` currently generates clearly labeled demo rounds. It is the server-side track provider boundary; a production Spotify implementation must obtain authorized track data server-side and write all rounds in that same protected transaction. The existing iOS Spotify code reads playlists but does not supply protected per-player tracks for the game. Demo rounds have no playable audio or album artwork.

## Profile privacy

Room members currently see numbered avatars and labels for other players. The existing `profiles` and `profile-photos` policies keep private display names and photos restricted. A proposed policy to expose those assets to room members was rejected by automatic approval review and was not deployed.

## Verification

The app compiles for the generic iOS Simulator destination. The live project has all multiplayer migrations and RLS enabled. A transaction using an authenticated existing user successfully created a room and read its membership, then rolled back. RPC grants were checked: anonymous users cannot execute game actions. A two-device round trip has not been run because the project currently has only one test profile in the connected database.
