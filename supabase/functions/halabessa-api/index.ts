import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@6";

const firebaseProject = "halabessa-card-game1";
const firebaseKeys = createRemoteJWKSet(new URL(
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
));
const allowedOrigins = new Set([
  "https://halabessa-card-game1.web.app",
  "https://halabessa-card-game1.firebaseapp.com",
  "http://localhost:3000",
  "http://localhost:5000",
]);

function headers(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin && allowedOrigins.has(origin) ? origin : "null",
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Content-Type": "application/json",
    Vary: "Origin",
  };
}

function reply(body: unknown, status: number, origin: string | null) {
  return new Response(JSON.stringify(body), { status, headers: headers(origin) });
}

async function firebaseUser(request: Request) {
  const bearer = request.headers.get("authorization");
  if (!bearer?.startsWith("Bearer ")) throw new Error("unauthenticated");
  const { payload } = await jwtVerify(bearer.slice(7), firebaseKeys, {
    audience: firebaseProject,
    issuer: `https://securetoken.google.com/${firebaseProject}`,
  });
  if (typeof payload.sub !== "string" || !payload.sub) throw new Error("unauthenticated");
  return {
    uid: payload.sub,
    email: typeof payload.email === "string" ? payload.email : null,
    name: typeof payload.name === "string" ? payload.name.slice(0, 64) : "Player",
  };
}

function database() {
  const secrets = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}") as Record<string, string>;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Object.values(secrets)[0];
  const url = Deno.env.get("SUPABASE_URL");
  if (!url || !key) throw new Error("server_not_configured");
  return createClient(url, key, { auth: { persistSession: false } }).schema("halabessa");
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: headers(origin) });
  if (origin && !allowedOrigins.has(origin)) return reply({ error: "origin_not_allowed" }, 403, origin);
  if (request.method === "GET") return reply({ ok: true, service: "halabessa-api" }, 200, origin);
  if (request.method !== "POST") return reply({ error: "method_not_allowed" }, 405, origin);

  try {
    const user = await firebaseUser(request);
    const body = await request.json() as { action?: string };
    if (body.action !== "bootstrapProfile") return reply({ error: "unsupported_action" }, 400, origin);
    const { error } = await database().from("user_profiles").upsert({
      firebase_uid: user.uid,
      email: user.email,
      display_name: user.name,
      updated_at: new Date().toISOString(),
    }, { onConflict: "firebase_uid", ignoreDuplicates: true });
    if (error) throw new Error("profile_bootstrap_failed");
    return reply({ ok: true, uid: user.uid }, 200, origin);
  } catch (error) {
    const message = error instanceof Error ? error.message : "internal_error";
    console.error("halabessa-api", { message });
    return reply({ error: message === "unauthenticated" ? message : "internal_error" }, message === "unauthenticated" ? 401 : 500, origin);
  }
});
