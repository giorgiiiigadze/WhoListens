import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const baseURL = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const clientID = "e1806c1092014fe9afb6719cbddd2319";
const redirectURI = "wholistens-spotify://callback";
const db = createClient(baseURL, serviceKey, { auth: { persistSession: false } });

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function newHandle(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function spotifyToken(params: URLSearchParams) {
  const secret = Deno.env.get("SPOTIFY_CLIENT_SECRET");
  if (!secret) throw new Error("Spotify client secret is not configured");
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      authorization: `Basic ${btoa(`${clientID}:${secret}`)}`,
      "content-type": "application/x-www-form-urlencoded",
    },
    body: params,
  });
  if (!response.ok) throw new Error(`Spotify token exchange failed (${response.status})`);
  return await response.json();
}

async function spotifyMe(accessToken: string): Promise<{ id: string; email?: string }> {
  const response = await fetch("https://api.spotify.com/v1/me", {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) throw new Error(`Spotify identity verification failed (${response.status})`);
  const profile = await response.json();
  if (typeof profile.id !== "string" || !profile.id) throw new Error("Spotify identity is missing");
  return profile;
}

async function swap(code: string) {
  const token = await spotifyToken(new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectURI,
  }));
  if (!token.access_token || !token.refresh_token) throw new Error("Spotify did not return refresh credentials");
  const profile = await spotifyMe(token.access_token);
  const handle = newHandle();
  const { data: existing, error: lookupError } = await db.from("spotify_accounts")
    .select("spotify_id").eq("spotify_id", profile.id).maybeSingle();
  if (lookupError) throw lookupError;
  const values = {
    refresh_handle_hash: await sha256(handle),
    refresh_token: token.refresh_token,
    updated_at: new Date().toISOString(),
  };
  const { error } = existing
    ? await db.from("spotify_accounts").update(values).eq("spotify_id", profile.id)
    : await db.from("spotify_accounts").insert({ spotify_id: profile.id, ...values });
  if (error) throw error;
  return { access_token: token.access_token, expires_in: token.expires_in, refresh_token: handle };
}

async function refresh(handle: string) {
  const hash = await sha256(handle);
  const { data: account, error } = await db.from("spotify_accounts")
    .select("spotify_id, refresh_token").eq("refresh_handle_hash", hash).maybeSingle();
  if (error || !account?.refresh_token) return json({ error: "Spotify connection expired" }, 401);
  const token = await spotifyToken(new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: account.refresh_token,
  }));
  if (token.refresh_token) {
    const { error: updateError } = await db.from("spotify_accounts")
      .update({ refresh_token: token.refresh_token, updated_at: new Date().toISOString() })
      .eq("spotify_id", account.spotify_id);
    if (updateError) throw updateError;
  }
  return json({ access_token: token.access_token, expires_in: token.expires_in });
}

async function exchange(accessToken: string, refreshHandle: string) {
  const profile = await spotifyMe(accessToken);
  if (!profile.email) return json({ error: "Spotify email permission is required" }, 400);
  const { data: account, error: accountError } = await db.from("spotify_accounts")
    .select("user_id, refresh_handle_hash").eq("spotify_id", profile.id).maybeSingle();
  if (accountError) throw accountError;
  if (!account || account.refresh_handle_hash !== await sha256(refreshHandle)) {
    return json({ error: "Spotify connection could not be verified" }, 401);
  }
  const { data: lookup, error: lookupError } = await db.rpc("spotify_auth_lookup", {
    p_spotify_id: profile.id, p_email: profile.email,
  });
  if (lookupError) throw lookupError;
  const existingIdentity = lookup?.[0]?.spotify_user_id as string | null;
  const emailOwner = lookup?.[0]?.email_user_id as string | null;
  const expectedUser = account?.user_id ?? existingIdentity;
  if (expectedUser && emailOwner && expectedUser !== emailOwner) {
    return json({ error: "Spotify email does not match the linked account" }, 409);
  }
  if (!expectedUser && emailOwner) {
    return json({ error: "This email is already linked to another account" }, 409);
  }

  const { data: link, error: linkError } = await db.auth.admin.generateLink({
    type: "magiclink", email: profile.email,
  });
  if (linkError || !link?.properties?.hashed_token || !link.user?.id) {
    throw linkError ?? new Error("Could not create a WhoListens session");
  }
  if (expectedUser && link.user.id !== expectedUser) {
    return json({ error: "Spotify account mapping does not match" }, 409);
  }
  const { error: bindError } = await db.from("spotify_accounts")
    .update({ user_id: link.user.id, updated_at: new Date().toISOString() })
    .eq("spotify_id", profile.id);
  if (bindError) throw bindError;
  return json({ token_hash: link.properties.hashed_token });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const path = new URL(request.url).pathname.split("/").at(-1);
  try {
    if (path === "swap" || path === "refresh") {
      const form = await request.formData();
      const value = form.get(path === "swap" ? "code" : "refresh_token");
      if (typeof value !== "string" || !value || value.length > 4096) {
        return json({ error: "Invalid credential" }, 400);
      }
      return path === "swap" ? json(await swap(value)) : await refresh(value);
    }
    if (path === "exchange") {
      const body = await request.json();
      if (typeof body.access_token !== "string" || !body.access_token || body.access_token.length > 4096 ||
          typeof body.refresh_handle !== "string" || !body.refresh_handle || body.refresh_handle.length > 4096) {
        return json({ error: "Invalid Spotify credentials" }, 400);
      }
      return await exchange(body.access_token, body.refresh_handle);
    }
    return json({ error: "Not found" }, 404);
  } catch (error) {
    console.error(error);
    return json({ error: "Spotify authentication failed" }, 502);
  }
});
