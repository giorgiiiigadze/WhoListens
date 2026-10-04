import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json", "cache-control": "no-store" },
});

const uuid = (value: unknown): value is string =>
  typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);

type Connection = {
  id: string;
  requester_id: string;
  addressee_id: string;
  status: "pending" | "accepted";
};

async function connectionList(userID: string): Promise<Connection[]> {
  const { data, error } = await db.from("friend_connections")
    .select("id, requester_id, addressee_id, status")
    .or(`requester_id.eq.${userID},addressee_id.eq.${userID}`);
  if (error) throw error;
  return data ?? [];
}

async function peerProfiles(ids: string[]) {
  if (!ids.length) return [];
  const { data, error } = await db.from("profiles")
    .select("id, display_name")
    .in("id", ids);
  if (error) throw error;
  return data ?? [];
}

async function list(userID: string) {
  const connections = await connectionList(userID);
  const profiles = await peerProfiles(connections.map((row) =>
    row.requester_id === userID ? row.addressee_id : row.requester_id
  ));
  const names = new Map(profiles.map((profile) => [profile.id, profile.display_name]));
  return json({ items: connections.map((row) => {
    const peerID = row.requester_id === userID ? row.addressee_id : row.requester_id;
    return {
      id: row.id,
      user: { id: peerID, display_name: names.get(peerID) ?? "Member" },
      status: row.status,
      direction: row.requester_id === userID ? "outgoing" : "incoming",
    };
  }) });
}

async function search(userID: string, input: unknown) {
  if (typeof input !== "string") return json({ error: "Search text required" }, 400);
  const query = input.trim().slice(0, 40);
  if (query.length < 2) return json({ items: [] });
  const escaped = query.replace(/[\\%_]/g, "\\$&");
  const { data, error } = await db.from("profiles")
    .select("id, display_name")
    .neq("id", userID)
    .ilike("display_name", `%${escaped}%`)
    .order("display_name")
    .limit(20);
  if (error) throw error;
  return json({ items: data ?? [] });
}

async function send(userID: string, peerID: unknown) {
  if (!uuid(peerID) || peerID === userID) return json({ error: "Invalid friend" }, 400);
  const profiles = await peerProfiles([peerID]);
  if (!profiles.length) return json({ error: "User not found" }, 404);
  const existing = (await connectionList(userID)).find((row) =>
    row.requester_id === peerID || row.addressee_id === peerID
  );
  if (existing) return json({ error: "A friend connection already exists" }, 409);
  const { error } = await db.from("friend_connections").insert({
    requester_id: userID,
    addressee_id: peerID,
    status: "pending",
  });
  if (error?.code === "23505") return json({ error: "A friend connection already exists" }, 409);
  if (error) throw error;
  return json({ ok: true });
}

async function change(userID: string, action: string, id: unknown) {
  if (!uuid(id)) return json({ error: "Invalid request" }, 400);
  let query;
  if (action === "accept") {
    query = db.from("friend_connections")
      .update({ status: "accepted", updated_at: new Date().toISOString() })
      .eq("id", id).eq("addressee_id", userID).eq("status", "pending");
  } else {
    query = db.from("friend_connections").delete().eq("id", id);
    if (action === "decline") query = query.eq("addressee_id", userID).eq("status", "pending");
    if (action === "cancel") query = query.eq("requester_id", userID).eq("status", "pending");
    if (action === "remove") {
      query = query.or(`requester_id.eq.${userID},addressee_id.eq.${userID}`)
        .eq("status", "accepted");
    }
  }
  const { data, error } = await query.select("id");
  if (error) throw error;
  if (!data?.length) return json({ error: "Request not found" }, 404);
  return json({ ok: true });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return json({ error: "Sign-in required" }, 401);
  const { data: auth, error: authError } = await db.auth.getUser(token);
  if (authError || !auth.user) return json({ error: "Sign-in required" }, 401);
  try {
    const body = await request.json();
    if (!body || typeof body !== "object") return json({ error: "Invalid request" }, 400);
    switch (body.action) {
      case "list": return await list(auth.user.id);
      case "search": return await search(auth.user.id, body.query);
      case "send": return await send(auth.user.id, body.user_id);
      case "accept":
      case "decline":
      case "cancel":
      case "remove": return await change(auth.user.id, body.action, body.id);
      default: return json({ error: "Unknown action" }, 400);
    }
  } catch (error) {
    console.error(error);
    return json({ error: "Friends request failed" }, 500);
  }
});
