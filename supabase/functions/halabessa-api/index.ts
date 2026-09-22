import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Pool } from "jsr:@db/postgres@^0";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@6";
import { cut, deal, playCard, startRound, type Card, type MatchState } from "./match_engine.ts";

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
const matchCommandTypes = new Set(["startRound", "cut", "dealInitial", "beginPlay", "dealSubsequent", "playCard"]);
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
    scope: "https://www.googleapis.com/auth/firebase.database https://www.googleapis.com/auth/userinfo.email",
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

function roomSummary(state: Record<string, unknown>) {
  return {
    mode: state.mode,
    playerIds: state.playerIds,
    isPublic: state.isPublic,
    phase: state.phase,
    ...(typeof state.expireAt === "string" ? { expireAt: state.expireAt } : {}),
  };
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

function publicMatchState(state: MatchState, version: number) {
  const publicState = { ...state } as Record<string, unknown>;
  const hands = objectPayload(publicState.handCards) as Record<string, unknown[]>;
  publicState.handCounts = Object.fromEntries(Object.entries(hands).map(([uid, cards]) => [uid, Array.isArray(cards) ? cards.length : 0]));
  publicState.serverVersion = version;
  delete publicState.handCards;
  return publicState;
}

function applyMatchCommand(
  commandType: string,
  state: MatchState,
  deck: Card[],
  actorUid: string,
  payload: Record<string, unknown>,
) {
  if (commandType === "startRound") return startRound(state, actorUid);
  if (commandType === "cut") return cut(state, deck, actorUid, payload.position);
  if (commandType === "dealInitial") return deal(state, deck, actorUid, true);
  if (commandType === "dealSubsequent") return deal(state, deck, actorUid, false);
  if (commandType === "beginPlay") {
    if (state.phase !== "dealingCards") throw new Error("play_not_ready");
    const playerIds = state.playerIds;
    const dealerIndex = Number.isInteger(state.dealerIndex) ? state.dealerIndex as number : -1;
    if (!Array.isArray(playerIds) || playerIds[dealerIndex] !== actorUid) {
      throw new Error("dealer_required");
    }
    return {
      state: { ...state, phase: "playing", turnStartTime: new Date().toISOString() } as MatchState,
      deck,
    };
  }
  if (commandType === "playCard") return { state: playCard(state, actorUid, payload.card), deck };
  throw new Error("unsupported_command");
}

async function isAdmin(connection: any, user: { uid: string; email: string | null }) {
  if (user.email?.toLowerCase() === primaryAdminEmail) return true;
  const result = await connection.queryObject<{ profile: Record<string, unknown> }>`
    select profile from halabessa.user_profiles where firebase_uid = ${user.uid}
  `;
  return result.rows[0]?.profile?.isAdmin === true;
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

  try {
    const user = await firebaseUser(request);
    const body = await request.json() as {
      action?: string;
      toUid?: unknown;
      fromUid?: unknown;
      accept?: unknown;
      roomId?: unknown;
      mode?: unknown;
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
    };
    const connection = await databasePool.connect();
    try {
      await connection.queryObject`
        insert into halabessa.user_profiles (firebase_uid, email, display_name)
        values (${user.uid}, ${user.email}, ${user.name})
        on conflict (firebase_uid) do update set
          email = excluded.email,
          display_name = excluded.display_name,
          updated_at = now()
      `;
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
          if (!playerIds.includes(user.uid)) {
            await connection.queryObject`rollback`;
            transactionOpen = false;
            return reply({ error: "not_room_participant" }, 403, origin);
          }
          const ownerProxy = room.owner_uid === user.uid && (
            requestedActor.startsWith("bot_") ||
            commandType === "dealInitial" ||
            commandType === "dealSubsequent" ||
            commandType === "beginPlay"
          );
          if (requestedActor !== user.uid && (!ownerProxy || !playerIds.includes(requestedActor))) {
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
            await connection.queryObject`commit`;
            transactionOpen = false;
            if (duplicate.rows[0].actor_uid !== user.uid ||
                duplicate.rows[0].action !== commandType ||
                Number(duplicate.rows[0].expected_version) !== expectedVersion ||
                !duplicate.rows[0].payload_matches) {
              return reply({ error: "command_id_conflict" }, 409, origin);
            }
            return reply(duplicate.rows[0].result, 200, origin);
          }
          if (currentVersion !== expectedVersion) {
            await connection.queryObject`rollback`;
            transactionOpen = false;
            return reply({ error: "version_conflict", currentVersion }, 409, origin);
          }

          const fullState = { ...room.state, handCards: room.hands ?? {} } as MatchState;
          let transition: { state: MatchState; deck: Card[] };
          try {
            transition = applyMatchCommand(commandType, fullState, room.deck ?? [], requestedActor, payload);
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
          const mirrored = await firebaseRequest("", "PATCH", {
            [`matches/${id}`]: publicState,
            [`matchHands/${id}`]: hands,
            [`matchSecrets/${id}`]: null,
            [`rooms/${id}`]: roomSummary(publicState),
          });
          if (mirrored.status < 200 || mirrored.status >= 300) throw new Error("match_mirror_failed");
          await connection.queryObject`commit`;
          transactionOpen = false;
          return reply(response, 200, origin);
        } catch (error) {
          if (transactionOpen) await connection.queryObject`rollback`;
          throw error;
        }
      }
      if (body.action === "createRoom") {
        if (!roomModes.has(body.mode as string) || !roomPoints.has(body.maxPoints as number) ||
            !roomTimers.has(body.timerDurationSeconds as number) || typeof body.isPublic !== "boolean") {
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
            serverVersion: 0,
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
          const seat = existing >= 0 ? existing : playerIds.findIndex((value) => typeof value === "string" && value.startsWith("waiting_"));
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
              const authoritative = await connection.queryObject<{ version: string }>`
                select version::text as version from halabessa.rooms where room_id = ${id} for update
              `;
              if (!authoritative.rows[0]) {
                await connection.queryObject`rollback`;
                transactionOpen = false;
                return reply({ error: "room_not_authoritative" }, 409, origin);
              }
              await connection.queryObject`
                update halabessa.rooms
                set state = ${JSON.stringify(match)}::jsonb,
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
        const friends = await connection.queryObject<{ uid: string }>`select friend_uid as uid from halabessa.friendships where owner_uid = ${user.uid}`;
        const incoming = await connection.queryObject<{ uid: string }>`select sender_uid as uid from halabessa.friend_requests where recipient_uid = ${user.uid}`;
        const outgoing = await connection.queryObject<{ uid: string }>`select recipient_uid as uid from halabessa.friend_requests where sender_uid = ${user.uid}`;
        const invites = await connection.queryObject<{ room_id: string; display_name: string }>`
          select i.room_id, p.display_name from halabessa.room_invites i
          join halabessa.user_profiles p on p.firebase_uid = i.sender_uid
          where i.recipient_uid = ${user.uid}
        `;
        return reply({
          friends: friends.rows.map((row) => row.uid),
          pendingFriendRequests: incoming.rows.map((row) => row.uid),
          sentFriendRequests: outgoing.rows.map((row) => row.uid),
          friendInvites: Object.fromEntries(invites.rows.map((row) => [row.room_id, row.display_name])),
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
