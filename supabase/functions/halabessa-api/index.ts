import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Pool } from "jsr:@db/postgres@^0";
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

const databaseUrl = Deno.env.get("SUPABASE_DB_URL");
if (!databaseUrl) throw new Error("server_not_configured");

// The schema deliberately stays out of Supabase's Data API. Edge Functions
// use the platform-provided database connection instead, so no table or RPC
// becomes reachable with a browser key.
const databasePool = new Pool(databaseUrl, 1);

function cairoDate() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Cairo", year: "numeric", month: "2-digit", day: "2-digit",
  }).formatToParts();
  const value = (type: string) => parts.find((part) => part.type === type)?.value;
  return `${value("year")}-${value("month")}-${value("day")}`;
}

function rewardStatus(daily: Record<string, unknown>, today: string) {
  const last = typeof daily.lastClaimDate === "string" ? daily.lastClaimDate : null;
  const prior = Number.isInteger(daily.streak) ? daily.streak as number : 0;
  const next = last === today ? Math.max(1, prior) :
    (last && Date.parse(`${today}T00:00:00Z`) - Date.parse(`${last}T00:00:00Z`) === 86400000 ? (prior % 7) + 1 : 1);
  const coins = [100, 200, 300, 400, 500, 750, 1500][next - 1];
  const diamonds = [0, 0, 1, 0, 2, 0, 5][next - 1];
  return { streak: next, isClaimableToday: last !== today, coins, diamonds };
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
    const connection = await databasePool.connect();
    try {
      await connection.queryObject`
        insert into halabessa.user_profiles (firebase_uid, email, display_name)
        values (${user.uid}, ${user.email}, ${user.name})
        on conflict (firebase_uid) do nothing
      `;
      if (body.action === "bootstrapProfile") return reply({ ok: true, uid: user.uid }, 200, origin);
      const today = cairoDate();
      if (body.action === "getDailyRewardStatus") {
        const result = await connection.queryObject<{ daily_reward: Record<string, unknown> }>`
          select daily_reward from halabessa.user_profiles where firebase_uid = ${user.uid}
        `;
        const profile = result.rows[0];
        if (!profile) throw new Error("profile_read_failed");
        return reply(rewardStatus(profile.daily_reward ?? {}, today), 200, origin);
      }
      if (body.action === "claimDailyReward") {
        const result = await connection.queryObject<{ streak: number; coins: number; diamonds: number }>`
          select * from halabessa.claim_daily_reward(${user.uid}, ${user.email}, ${user.name}, ${today}::date)
        `;
        const reward = result.rows[0];
        if (!reward) throw new Error("daily_claim_failed");
        return reply({ ok: true, ...reward, date: today }, 200, origin);
      }
      return reply({ error: "unsupported_action" }, 400, origin);
    } finally {
      connection.release();
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : "internal_error";
    console.error("halabessa-api", { message });
    if (message.includes("already_claimed")) return reply({ error: "already_claimed" }, 409, origin);
    return reply({ error: message === "unauthenticated" ? message : "internal_error" }, message === "unauthenticated" ? 401 : 500, origin);
  }
});
