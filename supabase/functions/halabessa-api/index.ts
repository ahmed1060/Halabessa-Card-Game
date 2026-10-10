import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Client } from "jsr:@db/postgres@0.19.5";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@6";
import { waitingSeatIndex, type Card, type MatchState } from "./match_engine.ts";
import { executeMatchIntent, matchCommandTypes } from "./match_commands.ts";
import { joinCommandRoom } from "./room_seating.ts";
import { roomSummary } from "./room_summary.ts";
import { rewardPlan } from "./match_rewards.ts";
import { createFirestoreRewardStore } from "./firestore_rewards.ts";
import { createPublicProfileStore } from "./public_profiles.ts";
import { assertNotDeletionBlocked } from "./deletion_access.ts";
import { assertAvatarUpload } from "./avatar_upload_policy.ts";
import { beginDeletion } from './account_deletion.ts';
import { createDeletionJobStore, deletionReceiptHash, recoverDeletion } from './deletion_job_store.ts';
import { createFirebaseIdentityStore, assertActiveIdentity } from './firebase_identity.ts';
import { runDeletionWorker } from './deletion_worker.ts';
import { createDatabaseRunner, databaseConnectionString } from "./database.ts";
import { createRequestTiming } from './request_timing.ts';
import { commitAndDeliver, deliverLatestRoom, matchMirrorUpdates, participantSnapshot, publicMatchState } from "./match_delivery.ts";

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
const firebaseDatabaseUrl = "https://halabessa-card-game1-default-rtdb.firebaseio.com";
const primaryAdminEmail = "ahmed.hossam1060@gmail.com";
const roomModes = new Set(["classic", "tafweet"]);
const roomPoints = new Set([21, 41, 61]);
const roomTimers = new Set([0, 5, 10, 15]);
const assetBucket = "game-assets";
const assetKinds = new Set(["avatar", "storeItem", "music", "sfx"]);
const assetExtensions = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
  ["audio/mpeg", "mp3"],
  ["audio/wav", "wav"],
  ["audio/mp4", "m4a"],
]);
let firebaseToken: { value: string; expiresAt: number } | null = null;

function headers(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin && allowedOrigins.has(origin) ? origin : "null",
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Max-Age": "600",
    "Cache-Control": "no-store",
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
    admin: payload.admin === true,
    authTime: typeof payload.auth_time === 'number' ? payload.auth_time : null,
    issuedAt: typeof payload.iat === 'number' ? payload.iat : null,
  };
}

async function firebaseAccessToken() {
  if (firebaseToken && firebaseToken.expiresAt > Date.now() + 60_000) return firebaseToken.value;
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("firebase_bridge_not_configured");
  const account = JSON.parse(raw) as { client_email?: string; private_key?: string; token_uri?: string };
  if (!account.client_email || !account.private_key || !account.token_uri) throw new Error("firebase_bridge_not_configured");
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(account.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.database https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/identitytoolkit",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience(account.token_uri)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const response = await fetch(account.token_uri, {
    method: "POST",
    signal: AbortSignal.timeout(12_000),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error("firebase_token_failed");
  const data = await response.json() as { access_token?: string; expires_in?: number };
  if (!data.access_token) throw new Error("firebase_token_failed");
  firebaseToken = { value: data.access_token, expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000 };
  return firebaseToken.value;
}

async function firebaseRequest(path: string, method = "GET", body?: unknown, etag?: string) {
  const token = await firebaseAccessToken();
  const response = await fetch(`${firebaseDatabaseUrl}/${path}.json`, {
    method,
    signal: AbortSignal.timeout(12_000),
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(method === "GET" ? { "X-Firebase-ETag": "true" } : {}),
      ...(etag ? { "if-match": etag } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  return { status: response.status, data: json, etag: response.headers.get("etag") };
}

function roomId() {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  const random = crypto.getRandomValues(new Uint32Array(8));
  return `${alphabet[random[0] % 26]}${alphabet[random[1] % 26]}${alphabet[random[2] % 26]}${String(random[3] % 100000).padStart(5, "0")}`;
}

function optionalText(value: unknown, maximum: number) {
  if (value == null) return "";
  if (typeof value !== "string" || value.length > maximum) throw new Error("invalid_room_configuration");
  return value.trim();
}

function validRoomId(value: unknown) {
  return typeof value === "string" && /^[A-Z]{3}[0-9]{5}$/.test(value) ? value : null;
}

function validCommandId(value: unknown) {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value.toLowerCase()
    : null;
}

function objectPayload(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

async function mirrorDurableRoom(connection: Client, id: string) {
  return deliverLatestRoom(async publish => {
    await connection.queryObject`begin`;
    try {
      const result = await connection.queryObject<{ state: MatchState; version: string; hands: Record<string, Card[]> }>`
        select r.state, r.version::text as version, s.hands
        from halabessa.rooms r join halabessa.room_secrets s on s.room_id = r.room_id
        where r.room_id = ${id} for update of r, s
      `;
      const row = result.rows[0];
      if (!row) throw new Error("room_not_found");
      const snapshot = await publish({ state: row.state, version: Number(row.version), hands: row.hands ?? {} });
      await connection.queryObject`commit`;
      return snapshot;
    } catch (error) {
      await connection.queryObject`rollback`;
      throw error;
    }
  }, async room => {
    const mirrored = await firebaseRequest("", "PATCH", matchMirrorUpdates(id, room, roomSummary));
    if (mirrored.status < 200 || mirrored.status >= 300) throw new Error("match_mirror_failed");
  });
}

async function isAdmin(connection: Client, user: { uid: string; email: string | null }) {
  if (user.email?.toLowerCase() === primaryAdminEmail) return true;
  const result = await connection.queryObject<{ profile: Record<string, unknown> }>`
    select profile from halabessa.user_profiles where firebase_uid = ${user.uid}
  `;
  return result.rows[0]?.profile?.isAdmin === true;
}

// The schema deliberately stays out of Supabase's Data API. Edge Functions
// open a connection only for authenticated work and close it before replying.
// DATABASE_POOLER_URL can select the shared transaction pooler (port 6543).
// The platform URL also remains safe from retained per-isolate idle sockets.
const withDatabase = createDatabaseRunner(() => new Client(databaseConnectionString(
  Deno.env.get("DATABASE_POOLER_URL") ?? Deno.env.get("SUPABASE_DB_URL"),
)));

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

function requiredUid(value: unknown, field: string, currentUid: string) {
  if (typeof value !== "string" || value.length < 1 || value.length > 128 || value === currentUid) {
    throw new Error(`invalid_${field}`);
  }
  return value;
}

function safeAssetKey(value: unknown) {
  if (typeof value !== "string") return "";
  return value.replace(/[^a-zA-Z0-9_-]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 80);
}

function decodeAsset(value: unknown, maximumBytes: number) {
  if (typeof value !== "string" || value.length === 0 || value.length > Math.ceil(maximumBytes * 4 / 3) + 8) {
    throw new Error("invalid_asset");
  }
  try {
    const binary = atob(value);
    if (binary.length === 0 || binary.length > maximumBytes) throw new Error("invalid_asset");
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    return bytes;
  } catch {
    throw new Error("invalid_asset");
  }
}

async function uploadAsset(
  body: { kind?: unknown; contentType?: unknown; base64?: unknown; assetKey?: unknown },
  user: { uid: string },
) {
  if (typeof body.kind !== "string" || !assetKinds.has(body.kind) ||
      typeof body.contentType !== "string" || !assetExtensions.has(body.contentType)) {
    throw new Error("invalid_asset");
  }
  assertAvatarUpload(body.kind, body.contentType, user.uid);
  const extension = assetExtensions.get(body.contentType)!;
  const maximumBytes = body.kind === "avatar" ? 2 * 1024 * 1024 : 4 * 1024 * 1024;
  const bytes = decodeAsset(body.base64, maximumBytes);
  const key = safeAssetKey(body.assetKey);
  if ((body.kind === "music" || body.kind === "sfx") && !key) throw new Error("invalid_asset");
  const path = body.kind === "avatar"
    ? `avatars/${safeAssetKey(user.uid)}/profile.${extension}`
    : body.kind === "storeItem"
    ? `store-items/${crypto.randomUUID()}.${extension}`
    : `audio/${body.kind}/${key}.${extension}`;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) throw new Error("storage_not_configured");
  const objectPath = path.split("/").map(encodeURIComponent).join("/");
  const response = await fetch(`${supabaseUrl}/storage/v1/object/${assetBucket}/${objectPath}`, {
    method: "POST",
    signal: AbortSignal.timeout(12_000),
    headers: {
      Authorization: `Bearer ${serviceRoleKey}`,
      apikey: serviceRoleKey,
      "Content-Type": body.contentType,
      "cache-control": "3600",
      "x-upsert": "true",
    },
    body: bytes,
  });
  if (!response.ok) {
    console.error("asset upload failed", { status: response.status, detail: await response.text() });
    throw new Error("asset_upload_failed");
  }
  return {
    path,
    publicUrl: `${supabaseUrl}/storage/v1/object/public/${assetBucket}/${objectPath}`,
  };
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: headers(origin) });
  if (origin && !allowedOrigins.has(origin)) return reply({ error: "origin_not_allowed" }, 403, origin);
  if (request.method === "GET") return reply({ ok: true, service: "halabessa-api" }, 200, origin);
  if (request.method !== "POST") return reply({ error: "method_not_allowed" }, 405, origin);

  const timing = createRequestTiming(record => console.log(JSON.stringify(record)));
  const runDatabase = <T>(work: (client: Client) => Promise<T>) => withDatabase(work, timing.observe);
  try {
    // Worker/receipt recovery must precede Firebase auth and normal profile
    // upserts: a disabled/deleted identity cannot be required to finish cleanup.
    const input = await request.json();
    timing.operation(input?.action);
    if (!input || typeof input !== 'object' || Array.isArray(input)) return reply({error:'invalid_request'},400,origin);
    if (input.action === 'accountDeletionStatus') {
      await deletionReceiptHash(input.receipt); // Reject malformed guesses before connecting.
      return await runDatabase(async connection => reply(await recoverDeletion(
        async (sql,args)=>(await connection.queryObject<Record<string,unknown>>(sql,args)).rows,
        input.receipt),200,origin));
    }
    if (input.action === 'continueAccountDeletion') {
      const workerKey=request.headers.get('x-deletion-worker');
      if(!workerKey || !/^[a-f0-9]{64}$/.test(workerKey))return reply({error:'unauthenticated'},401,origin);
      const keyHash=await deletionReceiptHash(workerKey);
      return await runDatabase(async connection=>{
        const query=async (sql:string,args:unknown[])=>(await connection.queryObject<Record<string,unknown>>(sql,args)).rows;
        const permitted=await query('select 1 from halabessa.deletion_worker_config where key_hash=$1',[keyHash]);
        if(!permitted.length)return reply({error:'unauthenticated'},401,origin);
        const jobs=await query(`select id::text from halabessa.account_deletion_jobs
          where status='pending' and (not apple_required or apple_revoked) order by updated_at limit 1`,[]);
        if(!jobs[0])return reply({ok:true,idle:true},200,origin);
        let status;
        try { status=await runDeletionWorker(query,String(jobs[0].id),{
          project:firebaseProject,databaseUrl:firebaseDatabaseUrl,
          storageUrl:Deno.env.get('SUPABASE_URL')??'',storageKey:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??'',
          token:firebaseAccessToken,
          settle:async(state,createdAt)=>{
            const plan=await rewardPlan(state,createdAt);
            await createFirestoreRewardStore(firebaseProject,firebaseAccessToken).settle(plan);
            return plan.receiptId;
          },
          publish:async(id,room)=>{
            const result=await firebaseRequest('','PATCH',matchMirrorUpdates(id,room,roomSummary));
            if(result.status<200 || result.status>=300)throw new Error('match_mirror_failed');
          },
        }); } catch(error) {
          // A SQL failure rolls back the lease, including its failure marker.
          // Rotate this pending job so one damaged/legacy record cannot starve
          // all other users' requests. Never convert failure into completion.
          if(!(error instanceof Error && error.message==='deletion_worker_busy')) {
            await query("update halabessa.account_deletion_jobs set updated_at=now() where id=$1::uuid and status='pending'",[jobs[0].id]);
          }
          return reply({ok:true,status:'pending'},200,origin);
        }
        return reply({ok:true,...status},200,origin);
      });
    }
    const user = await timing.measure('jwt', () => firebaseUser(request));
    if(input.action === 'requestAccountDeletion') {
      const receiptHash=await deletionReceiptHash(input.receipt);
      const identity=createFirebaseIdentityStore(firebaseProject,firebaseAccessToken);
      const account=await identity.lookup(user.uid);
      assertActiveIdentity(account,user.authTime);
      return await runDatabase(async connection=>{
        const query=async (sql:string,args:unknown[])=>(await connection.queryObject<Record<string,unknown>>(sql,args)).rows;
        const actor={...user,email:account!.email,admin:user.admin || account!.admin || await isAdmin(connection,user),verifiedGuest:account!.verifiedGuest};
        // Serialize acceptance with any existing profile mutation; no account
        // revocation occurs before the job has committed.
        await query('begin',[]);
        let job;
        try {
          await query('select firebase_uid from halabessa.user_profiles where firebase_uid=$1 for update',[user.uid]);
          job=await beginDeletion(createDeletionJobStore(query,receiptHash),actor,input,primaryAdminEmail,Math.floor(Date.now()/1000));
          await query('update halabessa.account_deletion_jobs set apple_required=$2 where id=$1::uuid',[job.id,account!.providers.includes('apple.com')]);
          await query('commit',[]);
        } catch(error) {await query('rollback',[]);throw error;}
        if(account!.providers.includes('apple.com')) {
          // Never trust a client boolean claiming that Apple was revoked. Send
          // its fresh credential to Firebase's revocation API, then persist the
          // verified success. Do not log or retain provider credentials.
          const apple=input.appleToken;
          const type=input.appleTokenType;
          if(typeof apple!=='string' || apple.length<1 || apple.length>8192 || !['CODE','ACCESS_TOKEN'].includes(type)) {
            return reply({id:job.id,status:'needs_apple_authorization'},202,origin);
          }
          const response=await fetch('https://identitytoolkit.googleapis.com/v2/accounts:revokeToken?key=AIzaSyC0zJJ488zNCBcy1ndWob5bx41gGbPnU5k',{
            method:'POST',signal:AbortSignal.timeout(12000),headers:{'Content-Type':'application/json'},
            body:JSON.stringify({providerId:'apple.com',tokenType:type,token:apple,
              idToken:request.headers.get('authorization')!.slice(7)}),
          });
          if(!response.ok)return reply({id:job.id,status:'needs_apple_authorization'},202,origin);
          await query('update halabessa.account_deletion_jobs set apple_revoked=true where id=$1::uuid',[job.id]);
        }
        return reply({id:job.id,status:job.status},202,origin);
      });
    }
    await timing.measure('deletion_guard', () => assertNotDeletionBlocked(user.uid, path => firebaseRequest(path)));
    const body = input as {
      action?: string;
      toUid?: unknown;
      fromUid?: unknown;
      accept?: unknown;
      roomId?: unknown;
      mode?: unknown;
      protocolVersion?: unknown;
      maxPoints?: unknown;
      timerDurationSeconds?: unknown;
      isPublic?: unknown;
      displayName?: unknown;
      cardBackId?: unknown;
      avatarUrl?: unknown;
      targetUid?: unknown;
      isAdmin?: unknown;
      kind?: unknown;
      fileName?: unknown;
      contentType?: unknown;
      base64?: unknown;
      assetKey?: unknown;
      commandId?: unknown;
      commandType?: unknown;
      expectedVersion?: unknown;
      commandPayload?: unknown;
      actorUid?: unknown;
      uid?: unknown;
      search?: unknown;
      category?: unknown;
      week?: unknown;
    };
    // Firestore-only discovery must not hold a scarce Postgres connection.
    if (body.action === 'getPublicProfile' || body.action === 'queryPublicProfiles') {
        const store = createPublicProfileStore(firebaseProject, firebaseAccessToken);
        try {
          return body.action === 'getPublicProfile'
            ? reply({ profile: await store.get(body.uid) }, 200, origin)
            : reply({ profiles: await store.query(body) }, 200, origin);
        } catch (error) {
          if (error instanceof Error && error.message === 'invalid_profile_query') return reply({error: error.message}, 400, origin);
          throw error;
        }
    }
    return await runDatabase(async (connection) => {
      // Defense in depth: once durable deletion is accepted, no ordinary API
      // request can bootstrap the deleted profile again. Receipt/worker actions
      // will use a separate authorized path rather than this normal upsert.
      const blocked = await connection.queryObject`
        select 1 from halabessa.account_deletion_jobs where firebase_uid = ${user.uid}
      `;
      if (blocked.rows.length) return reply({error:'unauthenticated'},401,origin);
      await timing.measure('profile_sync', () => connection.queryObject`
        insert into halabessa.user_profiles (firebase_uid, email, display_name)
        values (${user.uid}, ${user.email}, ${user.name})
        on conflict (firebase_uid) do update set
          email = excluded.email,
          display_name = excluded.display_name,
          updated_at = now()
        where halabessa.user_profiles.email is distinct from excluded.email
           or halabessa.user_profiles.display_name is distinct from excluded.display_name
      `);
      if (body.action === "uploadAsset") {
        if (body.kind !== "avatar" && !await isAdmin(connection, user)) {
          return reply({ error: "admin_required" }, 403, origin);
        }
        try {
          return reply({ ok: true, ...await uploadAsset(body, user) }, 200, origin);
        } catch (error) {
          const message = error instanceof Error ? error.message : "asset_upload_failed";
          if (message === "invalid_asset") return reply({ error: message }, 400, origin);
          throw error;
        }
      }
      if (body.action === "getAdminStatus") {
        return reply({ admin: await isAdmin(connection, user) }, 200, origin);
      }
      if (body.action === "setUserAdmin") {
        if (!await isAdmin(connection, user)) return reply({ error: "admin_required" }, 403, origin);
        if (typeof body.targetUid !== "string" || body.targetUid.length < 1 || body.targetUid.length > 128 || typeof body.isAdmin !== "boolean") {
          return reply({ error: "invalid_admin_update" }, 400, origin);
        }
        if (body.targetUid === user.uid && user.email?.toLowerCase() === primaryAdminEmail && !body.isAdmin) {
          return reply({ error: "primary_admin_required" }, 409, origin);
        }
        await connection.queryObject`insert into halabessa.user_profiles (firebase_uid) values (${body.targetUid}) on conflict do nothing`;
        await connection.queryObject`
          update halabessa.user_profiles
          set profile = jsonb_set(profile, '{isAdmin}', to_jsonb(${body.isAdmin}::boolean), true), updated_at = now()
          where firebase_uid = ${body.targetUid}
        `;
        return reply({ ok: true, targetUid: body.targetUid, admin: body.isAdmin }, 200, origin);
      }
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
      if (body.action === "submitMatchCommand") {
        const id = validRoomId(body.roomId);
        const commandId = validCommandId(body.commandId);
        const commandType = typeof body.commandType === "string" && matchCommandTypes.has(body.commandType)
          ? body.commandType
          : null;
        const expectedVersion = typeof body.expectedVersion === "number" && Number.isSafeInteger(body.expectedVersion) && body.expectedVersion >= 0
          ? body.expectedVersion
          : null;
        const payload = objectPayload(body.commandPayload);
        const payloadJson = JSON.stringify(payload);
        const requestedActor = typeof body.actorUid === "string" && body.actorUid.length <= 128 ? body.actorUid : user.uid;
        if (!id || !commandId || !commandType || expectedVersion == null || payloadJson.length > 4096) {
          return reply({ error: "invalid_match_command" }, 400, origin);
        }
        const ledgerPayload = { ...payload, actorUid: requestedActor };
        let transactionOpen = false;
        try {
          await connection.queryObject`begin`;
          transactionOpen = true;
          const authoritative = await connection.queryObject<{
            owner_uid: string;
            state: MatchState;
            version: string;
            deck: Card[];
            hands: Record<string, Card[]>;
          }>`
            select r.owner_uid, r.state, r.version::text as version, s.deck, s.hands
            from halabessa.rooms r
            join halabessa.room_secrets s on s.room_id = r.room_id
            where r.room_id = ${id}
            for update of r, s
          `;
          const room = authoritative.rows[0];
          if (!room) {
            await connection.queryObject`rollback`;
            transactionOpen = false;
            return reply({ error: "room_not_found" }, 404, origin);
          }
          const currentVersion = Number(room.version);
          const playerIds = Array.isArray(room.state.playerIds) ? room.state.playerIds : [];
          if (requestedActor !== user.uid) {
            await connection.queryObject`rollback`;
            transactionOpen = false;
            return reply({ error: "invalid_command_actor" }, 403, origin);
          }
          const duplicate = await connection.queryObject<{
            actor_uid: string;
            action: string;
            expected_version: string;
            payload_matches: boolean;
            result: Record<string, unknown>;
          }>`
            select actor_uid, action, expected_version::text as expected_version,
                   payload = ${JSON.stringify(ledgerPayload)}::jsonb as payload_matches,
                   result
            from halabessa.room_commands
            where room_id = ${id} and command_id = ${commandId}::uuid
          `;
          if (duplicate.rows[0]) {
            if (duplicate.rows[0].actor_uid !== user.uid ||
                duplicate.rows[0].action !== commandType ||
                Number(duplicate.rows[0].expected_version) !== expectedVersion ||
                !duplicate.rows[0].payload_matches) {
              await connection.queryObject`rollback`;
              transactionOpen = false;
              return reply({ error: "command_id_conflict" }, 409, origin);
            }
            const delivery = await commitAndDeliver(() => timing.measure('commit', async () => {
              await connection.queryObject`commit`;
              transactionOpen = false;
            }), () => timing.measure('mirror', () => mirrorDurableRoom(connection, id)));
            return reply({ ...duplicate.rows[0].result,
              appliedVersion: duplicate.rows[0].result.version,
              ...participantSnapshot(delivery.snapshot ?? {
                state: room.state, version: currentVersion, hands: room.hands ?? {},
              }, user.uid), duplicate: true, mirrorPending: delivery.mirrorPending }, 200, origin);
          }
          if (!playerIds.includes(user.uid)) {
            await connection.queryObject`rollback`;
            transactionOpen = false;
            return reply({ error: "not_room_participant" }, 403, origin);
          }
          if (currentVersion !== expectedVersion) {
            await connection.queryObject`rollback`;
            transactionOpen = false;
            return reply({ error: "version_conflict", currentVersion,
              ...participantSnapshot({ state: room.state, version: currentVersion, hands: room.hands ?? {} }, user.uid),
            }, 409, origin);
          }

          const fullState = { ...room.state, handCards: room.hands ?? {} } as MatchState;
          let transition: { state: MatchState; deck: Card[] };
          try {
            transition = executeMatchIntent(commandType, fullState, room.deck ?? [], user.uid, requestedActor, payload);
          } catch (error) {
            await connection.queryObject`rollback`;
            transactionOpen = false;
            const reason = error instanceof Error ? error.message : "command_rejected";
            return reply({ error: "command_rejected", reason, currentVersion }, 409, origin);
          }
          const appliedVersion = currentVersion + 1;
          const hands = transition.state.handCards ?? {};
          const publicState = publicMatchState(transition.state, appliedVersion);
          const ledgerResult = {
            ok: true,
            roomId: id,
            commandId,
            commandType,
            version: appliedVersion,
            appliedVersion,
            actorUid: requestedActor,
          };
          const response = { ...ledgerResult, state: publicState, hand: hands[user.uid] ?? [] };
          await connection.queryObject`
            update halabessa.rooms
            set state = ${JSON.stringify(publicState)}::jsonb,
                version = ${appliedVersion},
                expires_at = ${typeof publicState.expireAt === "string" ? publicState.expireAt : null}::timestamptz,
                updated_at = now()
            where room_id = ${id}
          `;
          await connection.queryObject`
            update halabessa.room_secrets
            set deck = ${JSON.stringify(transition.deck)}::jsonb,
                hands = ${JSON.stringify(hands)}::jsonb
            where room_id = ${id}
          `;
          await connection.queryObject`
            insert into halabessa.room_commands
              (room_id, command_id, actor_uid, action, expected_version, applied_version, payload, result)
            values
              (${id}, ${commandId}::uuid, ${user.uid}, ${commandType}, ${expectedVersion}, ${appliedVersion},
               ${JSON.stringify(ledgerPayload)}::jsonb, ${JSON.stringify(response)}::jsonb)
          `;
          const delivery = await commitAndDeliver(() => timing.measure('commit', async () => {
            await connection.queryObject`commit`;
            transactionOpen = false;
          }), () => timing.measure('mirror', () => mirrorDurableRoom(connection, id)));
          if (delivery.mirrorPending) console.warn("halabessa-match: committed command awaits mirror repair");
          return reply({ ...response,
            ...participantSnapshot(delivery.snapshot ?? {
              state: publicState, version: appliedVersion, hands,
            }, user.uid), mirrorPending: delivery.mirrorPending }, 200, origin);
        } catch (error) {
          if (transactionOpen) await connection.queryObject`rollback`;
          throw error;
        }
      }
      if (body.action === "getMatchSnapshot") {
        const id = validRoomId(body.roomId);
        if (!id) return reply({ error: "invalid_room_id" }, 400, origin);
        const result = await connection.queryObject<{ state: MatchState; version: string; hands: Record<string, Card[]> }>`
          select r.state, r.version::text as version, s.hands
          from halabessa.rooms r join halabessa.room_secrets s on s.room_id = r.room_id
          where r.room_id = ${id}
        `;
        const room = result.rows[0];
        if (!room) return reply({ error: "room_not_found" }, 404, origin);
        if (!(room.state.playerIds ?? []).includes(user.uid)) return reply({ error: "not_room_participant" }, 403, origin);
        return reply(participantSnapshot({ state: room.state, version: Number(room.version), hands: room.hands ?? {} }, user.uid), 200, origin);
      }
      if (body.action === "settleMatchRewards") {
        const id = validRoomId(body.roomId);
        if (!id) return reply({ error: "invalid_room_id" }, 400, origin);
        let transactionOpen = false;
        try {
          await connection.queryObject`begin`; transactionOpen = true;
          const result = await connection.queryObject<{ state: MatchState; version: string;
            hands: Record<string, Card[]>; created_at: string }>`
            select r.state, r.version::text as version, extract(epoch from r.created_at)::text as created_at, s.hands
            from halabessa.rooms r join halabessa.room_secrets s on s.room_id = r.room_id
            where r.room_id = ${id} for update of r, s
          `;
          const room = result.rows[0];
          if (!room || !(room.state.playerIds ?? []).includes(user.uid)) {
            await connection.queryObject`rollback`; transactionOpen = false;
            return reply({ error: "not_room_participant" }, 403, origin);
          }
          if (room.state.protocolVersion !== 1 || !["rematchVoting", "matchOver"].includes(String(room.state.phase))) {
            await connection.queryObject`rollback`; transactionOpen = false;
            return reply({ error: "rewards_not_ready" }, 409, origin);
          }
          let state = room.state, version = Number(room.version);
          let duplicate = true;
          if (state.settlementPending !== true && !/^[a-f0-9]{64}$/.test(String(state.rewardReceiptId ?? ""))) {
            throw new Error("rewards_not_ready");
          }
          if (state.settlementPending === true) {
            const plan = await rewardPlan(state, room.created_at);
            const settled = await createFirestoreRewardStore(firebaseProject, firebaseAccessToken).settle(plan);
            duplicate = settled.duplicate;
            state = { ...state, settlementPending: false, rewardReceiptId: plan.receiptId };
            version++;
            await connection.queryObject`update halabessa.rooms
              set state = ${JSON.stringify(publicMatchState({ ...state, handCards: room.hands ?? {} }, version))}::jsonb,
                  version = ${version}, updated_at = now() where room_id = ${id}`;
          }
          const delivery = await commitAndDeliver(() => timing.measure('commit', async () => {
            await connection.queryObject`commit`; transactionOpen = false;
          }), () => timing.measure('mirror', () => mirrorDurableRoom(connection, id)));
          return reply({ ok: true, settled: true, duplicate,
            ...participantSnapshot(delivery.snapshot ?? { state, version, hands: room.hands ?? {} }, user.uid),
            mirrorPending: delivery.mirrorPending }, 200, origin);
        } catch (error) {
          if (transactionOpen) await connection.queryObject`rollback`;
          const safeReasons = new Set(["rewards_not_ready", "invalid_reward_state", "invalid_reward_profile",
            "reward_profile_missing", "reward_access_denied", "reward_store_failed", "reward_transport_failed",
            "reward_receipt_conflict", "reward_settlement_retry_required"]);
          const reason = error instanceof Error && safeReasons.has(error.message) ? error.message : "reward_store_failed";
          console.warn("halabessa-match: reward settlement remains pending", { reason });
          return reply({ error: "reward_settlement_pending", reason }, 503, origin);
        }
      }
      if (body.action === "createRoom") {
        if (!roomModes.has(body.mode as string) || !roomPoints.has(body.maxPoints as number) ||
            !roomTimers.has(body.timerDurationSeconds as number) || typeof body.isPublic !== "boolean" ||
            (body.protocolVersion != null && body.protocolVersion !== 0 && body.protocolVersion !== 1)) {
          return reply({ error: "invalid_room_configuration" }, 400, origin);
        }
        const displayName = optionalText(body.displayName, 64) || user.name;
        const cardBackId = optionalText(body.cardBackId, 64);
        const avatarUrl = optionalText(body.avatarUrl, 2048);
        for (let attempt = 0; attempt < 5; attempt += 1) {
          const id = roomId();
          const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();
          const match = {
            id, mode: body.mode, maxPoints: body.maxPoints,
            playerIds: [user.uid, "waiting_1", "waiting_2", "waiting_3"],
            players: { [user.uid]: true }, playerNames: { [user.uid]: displayName },
            playerSkins: { [user.uid]: cardBackId }, playerAvatars: { [user.uid]: avatarUrl },
            dealerIndex: 0, currentTurnIndex: 1, phase: "waitingForPlayers",
            timerDurationSeconds: body.timerDurationSeconds, isPublic: body.isPublic, expireAt: expiresAt,
            serverVersion: 0, protocolVersion: body.protocolVersion === 1 ? 1 : 0,
          };
          let transactionOpen = false;
          let firebaseCreated = false;
          try {
            await connection.queryObject`begin`;
            transactionOpen = true;
            const inserted = await connection.queryObject<{ room_id: string }>`
              insert into halabessa.rooms (room_id, owner_uid, state, expires_at)
              values (${id}, ${user.uid}, ${JSON.stringify(match)}::jsonb, ${expiresAt}::timestamptz)
              on conflict do nothing
              returning room_id
            `;
            if (!inserted.rows[0]) {
              await connection.queryObject`rollback`;
              transactionOpen = false;
              continue;
            }
            await connection.queryObject`
              insert into halabessa.room_secrets (room_id) values (${id})
            `;
            const created = await firebaseRequest(`matches/${id}`, "PUT", match, "null_etag");
            if (created.status === 412) {
              await connection.queryObject`rollback`;
              transactionOpen = false;
              continue;
            }
            if (created.status < 200 || created.status >= 300) throw new Error("room_create_failed");
            firebaseCreated = true;
            const indexed = await firebaseRequest(`rooms/${id}`, "PUT", roomSummary(match));
            if (indexed.status < 200 || indexed.status >= 300) throw new Error("room_index_failed");
            await connection.queryObject`commit`;
            transactionOpen = false;
            return reply({ roomId: id, match, version: 0 }, 200, origin);
          } catch (error) {
            if (transactionOpen) await connection.queryObject`rollback`;
            if (firebaseCreated) {
              const cleanup = await firebaseRequest("", "PATCH", {
                [`matches/${id}`]: null,
                [`rooms/${id}`]: null,
              });
              if (cleanup.status < 200 || cleanup.status >= 300) {
                console.error("room create compensation failed", { roomId: id, status: cleanup.status });
              }
            }
            throw error;
          }
        }
        throw new Error("room_create_failed");
      }
      if (body.action === "joinRoom") {
        const id = typeof body.roomId === "string" && /^[A-Z]{3}[0-9]{5}$/.test(body.roomId) ? body.roomId : null;
        if (!id) return reply({ error: "invalid_room_id" }, 400, origin);
        const displayName = optionalText(body.displayName, 64) || user.name;
        const cardBackId = optionalText(body.cardBackId, 64);
        const avatarUrl = optionalText(body.avatarUrl, 2048);
        // Versioned rooms never import a potentially stale/mutable Firebase
        // mirror. Joining/replacement and command application share SQL locks.
        let joinTransactionOpen = false;
        try {
          await connection.queryObject`begin`;
          joinTransactionOpen = true;
          const locked = await connection.queryObject<{ state: MatchState; version: string; hands: Record<string, Card[]> }>`
            select r.state, r.version::text as version, s.hands
            from halabessa.rooms r join halabessa.room_secrets s on s.room_id = r.room_id
            where r.room_id = ${id} for update of r, s
          `;
          const room = locked.rows[0];
          if (room && (Number(room.version) > 0 || room.state.protocolVersion === 1)) {
            let joined;
            try {
              joined = joinCommandRoom({ ...room.state, handCards: room.hands ?? {} }, user.uid,
                { displayName, cardBackId, avatarUrl });
            } catch (error) {
              await connection.queryObject`rollback`; joinTransactionOpen = false;
              return reply({ error: error instanceof Error ? error.message : "room_not_joinable" }, 409, origin);
            }
            const version = Number(room.version) + (joined.alreadyJoined ? 0 : 1);
            const publicState = publicMatchState(joined.state, version);
            const hands = joined.state.handCards ?? {};
            if (!joined.alreadyJoined) {
              await connection.queryObject`update halabessa.rooms
                set state = ${JSON.stringify(publicState)}::jsonb, version = ${version}, updated_at = now()
                where room_id = ${id}`;
              await connection.queryObject`update halabessa.room_secrets
                set hands = ${JSON.stringify(hands)}::jsonb where room_id = ${id}`;
            }
            await connection.queryObject`delete from halabessa.room_invites where room_id = ${id} and recipient_uid = ${user.uid}`;
            const delivery = await commitAndDeliver(() => timing.measure('commit', async () => {
              await connection.queryObject`commit`; joinTransactionOpen = false;
            }), () => timing.measure('mirror', () => mirrorDurableRoom(connection, id)));
            const snapshot = participantSnapshot(delivery.snapshot ?? { state: publicState, version, hands }, user.uid);
            return reply({ roomId: id, match: snapshot.state, ...snapshot,
              seatIndex: joined.seatIndex, alreadyJoined: joined.alreadyJoined,
              mirrorPending: delivery.mirrorPending }, 200, origin);
          }
          await connection.queryObject`rollback`; joinTransactionOpen = false;
        } catch (error) {
          if (joinTransactionOpen) await connection.queryObject`rollback`;
          throw error;
        }
        for (let attempt = 0; attempt < 5; attempt += 1) {
          const current = await firebaseRequest(`matches/${id}`);
          const match = current.data as Record<string, unknown> | null;
          if (current.status !== 200 || !match) return reply({ error: "room_not_found" }, 404, origin);
          if (match.phase !== "waitingForPlayers" || (typeof match.expireAt === "string" && Date.parse(match.expireAt) <= Date.now())) {
            return reply({ error: "room_not_joinable" }, 409, origin);
          }
          const playerIds = Array.isArray(match.playerIds) ? [...match.playerIds] : [];
          if (playerIds.length !== 4) return reply({ error: "invalid_room_state" }, 409, origin);
          const existing = playerIds.indexOf(user.uid);
          const seat = existing >= 0 ? existing : waitingSeatIndex(playerIds);
          if (seat < 0) return reply({ error: "room_full" }, 409, origin);
          if (existing < 0) {
            playerIds[seat] = user.uid;
            match.playerIds = playerIds;
            match.players = { ...(match.players as Record<string, boolean> ?? {}), [user.uid]: true };
            match.playerNames = { ...(match.playerNames as Record<string, string> ?? {}), [user.uid]: displayName };
            match.playerSkins = { ...(match.playerSkins as Record<string, string> ?? {}), [user.uid]: cardBackId };
            match.playerAvatars = { ...(match.playerAvatars as Record<string, string> ?? {}), [user.uid]: avatarUrl };
            let transactionOpen = false;
            try {
              await connection.queryObject`begin`;
              transactionOpen = true;
              const authoritative = await connection.queryObject<{ version: string; protocol_version: unknown }>`
                select version::text as version, state->'protocolVersion' as protocol_version
                from halabessa.rooms where room_id = ${id} for update
              `;
              if (!authoritative.rows[0]) {
                await connection.queryObject`rollback`;
                transactionOpen = false;
                return reply({ error: "room_not_authoritative" }, 409, origin);
              }
              if (Number(authoritative.rows[0].version) > 0 || authoritative.rows[0].protocol_version === 1) {
                await connection.queryObject`rollback`;
                transactionOpen = false;
                return reply({ error: "room_changed_retry" }, 409, origin);
              }
              await connection.queryObject`
                update halabessa.rooms
                set state = ${JSON.stringify({ ...match, protocolVersion: 0 })}::jsonb,
                    expires_at = ${typeof match.expireAt === "string" ? match.expireAt : null}::timestamptz,
                    updated_at = now()
                where room_id = ${id}
              `;
              const written = await firebaseRequest(`matches/${id}`, "PUT", match, current.etag ?? undefined);
              if (written.status === 412) {
                await connection.queryObject`rollback`;
                transactionOpen = false;
                continue;
              }
              if (written.status < 200 || written.status >= 300) throw new Error("room_join_failed");
              const indexed = await firebaseRequest(`rooms/${id}`, "PUT", roomSummary(match));
              if (indexed.status < 200 || indexed.status >= 300) throw new Error("room_index_failed");
              await connection.queryObject`delete from halabessa.room_invites where room_id = ${id} and recipient_uid = ${user.uid}`;
              await connection.queryObject`commit`;
              transactionOpen = false;
              return reply({
                roomId: id,
                match,
                seatIndex: seat,
                alreadyJoined: false,
                version: Number(authoritative.rows[0].version),
              }, 200, origin);
            } catch (error) {
              if (transactionOpen) await connection.queryObject`rollback`;
              throw error;
            }
          }
          const indexed = await firebaseRequest(`rooms/${id}`, "PUT", roomSummary(match));
          if (indexed.status < 200 || indexed.status >= 300) throw new Error("room_index_failed");
          await connection.queryObject`delete from halabessa.room_invites where room_id = ${id} and recipient_uid = ${user.uid}`;
          const authoritative = await connection.queryObject<{ version: string }>`
            select version::text as version from halabessa.rooms where room_id = ${id}
          `;
          if (!authoritative.rows[0]) return reply({ error: "room_not_authoritative" }, 409, origin);
          return reply({ roomId: id, match, seatIndex: seat, alreadyJoined: true, version: Number(authoritative.rows[0].version) }, 200, origin);
        }
        return reply({ error: "room_changed_retry" }, 409, origin);
      }
      if (body.action === "refreshRoomIndex") {
        const id = typeof body.roomId === "string" && /^[A-Z]{3}[0-9]{5}$/.test(body.roomId) ? body.roomId : null;
        if (!id) return reply({ error: "invalid_room_id" }, 400, origin);
        const current = await firebaseRequest(`matches/${id}`);
        const match = current.data as Record<string, unknown> | null;
        if (!match) return reply({ error: "room_not_found" }, 404, origin);
        const players = match.players as Record<string, boolean> | undefined;
        if (!players?.[user.uid]) return reply({ error: "not_room_participant" }, 403, origin);
        const indexed = await firebaseRequest(`rooms/${id}`, "PUT", roomSummary(match));
        if (indexed.status < 200 || indexed.status >= 300) throw new Error("room_index_failed");
        return reply({ ok: true, roomId: id }, 200, origin);
      }
      if (body.action === "deleteRoom") {
        if (!await isAdmin(connection, user)) return reply({ error: "admin_required" }, 403, origin);
        const id = typeof body.roomId === "string" && /^[A-Z]{3}[0-9]{5}$/.test(body.roomId) ? body.roomId : null;
        if (!id) return reply({ error: "invalid_room_id" }, 400, origin);
        let transactionOpen = false;
        try {
          await connection.queryObject`begin`;
          transactionOpen = true;
          await connection.queryObject`delete from halabessa.rooms where room_id = ${id}`;
          const deleted = await firebaseRequest("", "PATCH", {
            [`matches/${id}`]: null,
            [`matchHands/${id}`]: null,
            [`matchSecrets/${id}`]: null,
            [`matchChat/${id}`]: null,
            [`rooms/${id}`]: null,
          });
          if (deleted.status < 200 || deleted.status >= 300) throw new Error("room_delete_failed");
          await connection.queryObject`commit`;
          transactionOpen = false;
          return reply({ ok: true, roomId: id }, 200, origin);
        } catch (error) {
          if (transactionOpen) await connection.queryObject`rollback`;
          throw error;
        }
      }
      if (body.action === "sendRoomInvite") {
        const id = typeof body.roomId === "string" && /^[A-Z]{3}[0-9]{5}$/.test(body.roomId) ? body.roomId : null;
        const toUid = requiredUid(body.toUid, "to_uid", user.uid);
        if (!id) return reply({ error: "invalid_room_id" }, 400, origin);
        const current = await firebaseRequest(`matches/${id}`);
        const match = current.data as Record<string, unknown> | null;
        const players = match?.players as Record<string, boolean> | undefined;
        const playerIds = Array.isArray(match?.playerIds) ? match.playerIds : [];
        if (!match || match.phase !== "waitingForPlayers" || !players?.[user.uid] ||
            (typeof match.expireAt === "string" && Date.parse(match.expireAt) <= Date.now()) ||
            playerIds.includes(toUid)) {
          return reply({ error: "room_not_invitable" }, 409, origin);
        }
        const friendship = await connection.queryObject<{ friend_uid: string }>`
          select friend_uid from halabessa.friendships where owner_uid = ${user.uid} and friend_uid = ${toUid}
        `;
        if (!friendship.rows[0]) return reply({ error: "not_friends" }, 403, origin);
        await connection.queryObject`insert into halabessa.user_profiles (firebase_uid) values (${toUid}) on conflict do nothing`;
        await connection.queryObject`
          insert into halabessa.room_invites (room_id, recipient_uid, sender_uid)
          values (${id}, ${toUid}, ${user.uid})
          on conflict (room_id, recipient_uid) do update set sender_uid = excluded.sender_uid, created_at = now()
        `;
        return reply({ ok: true, roomId: id }, 200, origin);
      }
      if (body.action === "getSocialGraph") {
        // One network round trip and one MVCC snapshot, with the same indexed
        // predicates and response schema as the previous four queries.
        const graph = await timing.measure('social_query', () => connection.queryObject<{
          friends: string[]; incoming: string[]; outgoing: string[]; invites: Record<string, string>;
        }>`select
          coalesce((select jsonb_agg(friend_uid) from halabessa.friendships where owner_uid=${user.uid}), '[]'::jsonb) as friends,
          coalesce((select jsonb_agg(sender_uid) from halabessa.friend_requests where recipient_uid=${user.uid}), '[]'::jsonb) as incoming,
          coalesce((select jsonb_agg(recipient_uid) from halabessa.friend_requests where sender_uid=${user.uid}), '[]'::jsonb) as outgoing,
          coalesce((select jsonb_object_agg(i.room_id, p.display_name) from halabessa.room_invites i
            join halabessa.user_profiles p on p.firebase_uid=i.sender_uid
            where i.recipient_uid=${user.uid}), '{}'::jsonb) as invites`);
        const social = graph.rows[0];
        return reply({
          friends: social.friends,
          pendingFriendRequests: social.incoming,
          sentFriendRequests: social.outgoing,
          friendInvites: social.invites,
        }, 200, origin);
      }
      if (body.action === "sendFriendRequest") {
        const toUid = requiredUid(body.toUid, "to_uid", user.uid);
        await connection.queryObject`insert into halabessa.user_profiles (firebase_uid) values (${toUid}) on conflict do nothing`;
        await connection.queryObject`
          insert into halabessa.friend_requests (sender_uid, recipient_uid) values (${user.uid}, ${toUid})
          on conflict do nothing
        `;
        return reply({ ok: true }, 200, origin);
      }
      if (body.action === "respondToFriendRequest") {
        const fromUid = requiredUid(body.fromUid, "from_uid", user.uid);
        const accepted = body.accept === true;
        const request = await connection.queryObject<{ sender_uid: string }>`
          delete from halabessa.friend_requests
          where sender_uid = ${fromUid} and recipient_uid = ${user.uid}
          returning sender_uid
        `;
        if (!request.rows[0]) return reply({ error: "friend_request_not_found" }, 404, origin);
        if (accepted) {
          await connection.queryObject`
            insert into halabessa.friendships (owner_uid, friend_uid)
            values (${user.uid}, ${fromUid}), (${fromUid}, ${user.uid})
            on conflict do nothing
          `;
        }
        return reply({ ok: true, accepted }, 200, origin);
      }
      return reply({ error: "unsupported_action" }, 400, origin);
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "internal_error";
    console.error("halabessa-api", { message });
    if (message === "database_busy" ||
        (error && typeof error === "object" && "fields" in error &&
         (error.fields as { code?: string } | undefined)?.code === "53300")) {
      return new Response(JSON.stringify({ error: "backend_busy" }), {
        status: 503, headers: { ...headers(origin), "Retry-After": "1" },
      });
    }
    if (message.includes("already_claimed")) return reply({ error: "already_claimed" }, 409, origin);
    if(['protected_account','requires_recent_login','deletion_confirmation_required','deletion_target_forbidden',
      'invalid_deletion_receipt','deletion_receipt_conflict'].includes(message))return reply({error:message},400,origin);
    if (error && typeof error === 'object' && 'fields' in error &&
        (error.fields as {code?: string; message?: string} | undefined)?.code === 'P0001' &&
        (error.fields as {message?: string} | undefined)?.message === 'account_unavailable') {
      return reply({error:'account_unavailable'},409,origin);
    }
    return reply({ error: message === "unauthenticated" ? message : "internal_error" }, message === "unauthenticated" ? 401 : 500, origin);
  } finally {
    timing.finish();
  }
});
