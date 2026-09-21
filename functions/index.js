const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const crypto = require("crypto");
const matchEngine = require("./match_engine");
admin.initializeApp();

// Only this exact account can ever be granted admin, and only the account
// itself can claim it -- see HAL-08. Nothing else in this file, and nothing
// on the client, can set this claim.
const ADMIN_EMAIL = "ahmed.hossam1060@gmail.com";

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  return request.auth;
}

const ROOM_ID_PATTERN = /^[A-Z]{3}[0-9]{5}$/;
const ROOM_MODES = new Set(["classic", "tafweet"]);
const ROOM_POINTS = new Set([21, 41, 61]);
const ROOM_TIMERS = new Set([0, 5, 10, 15]);

function requireRoomId(value) {
  if (typeof value !== "string" || !ROOM_ID_PATTERN.test(value)) {
    throw new HttpsError("invalid-argument", "A valid room id is required.");
  }
  return value;
}

function optionalText(value, field, maxLength) {
  if (value == null) return "";
  if (typeof value !== "string" || value.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} must be a string of at most ${maxLength} characters.`);
  }
  return value.trim();
}

function roomSummary(match) {
  return {
    mode: match.mode,
    playerIds: match.playerIds,
    isPublic: match.isPublic,
    phase: match.phase,
    ...(match.expireAt ? { expireAt: match.expireAt } : {}),
  };
}

async function refreshRoomIndex(roomId) {
  const db = admin.database();
  const snapshot = await db.ref(`matches/${roomId}`).once("value");
  const match = snapshot.val();
  if (!match) {
    await db.ref(`rooms/${roomId}`).remove();
    return null;
  }
  await db.ref(`rooms/${roomId}`).set(roomSummary(match));
  return match;
}

function createRoomId() {
  const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  let id = "";
  for (let i = 0; i < 3; i++) id += letters[crypto.randomInt(letters.length)];
  for (let i = 0; i < 5; i++) id += crypto.randomInt(10).toString();
  return id;
}

const DAILY_REWARDS = [
  { coins: 100, diamonds: 0 },
  { coins: 200, diamonds: 0 },
  { coins: 300, diamonds: 1 },
  { coins: 400, diamonds: 0 },
  { coins: 500, diamonds: 2 },
  { coins: 750, diamonds: 0 },
  { coins: 1500, diamonds: 5 },
];

function cairoDateKey(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const part = (type) => parts.find((entry) => entry.type === type)?.value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}

function calendarDayDistance(earlier, later) {
  const parse = (value) => {
    const [year, month, day] = value.split("-").map(Number);
    return Date.UTC(year, month - 1, day) / 86400000;
  };
  return parse(later) - parse(earlier);
}

function dailyRewardStatus(daily, today) {
  const priorStreak = Number.isInteger(daily?.streak) ? daily.streak : 0;
  const claimedToday = daily?.lastClaimDate === today;
  const streak = claimedToday
    ? Math.max(1, priorStreak)
    : (typeof daily?.lastClaimDate === "string" &&
        /^\d{4}-\d{2}-\d{2}$/.test(daily.lastClaimDate) &&
        calendarDayDistance(daily.lastClaimDate, today) === 1
      ? (priorStreak % DAILY_REWARDS.length) + 1
      : 1);
  return { streak, claimedToday, reward: DAILY_REWARDS[streak - 1] };
}

// ---------------------------------------------------------------------------
// Admin claims (HAL-08)
//
// The app used to compute `isAdmin` in the client from a hardcoded email
// check and persist it to `users/$uid`, a path the signed-in user is
// themselves allowed to write -- so any user could grant themselves admin by
// writing `isAdmin: true` to their own profile. Real authorization now lives
// entirely in the Firebase Auth custom claim these two functions set, which
// only the Admin SDK (server-side) can touch. The client calls
// grantAdminIfEligible once per sign-in and reads request.auth.token.admin
// (never a database field) to decide what to show.
// ---------------------------------------------------------------------------

exports.grantAdminIfEligible = onCall(async (request) => {
  const auth = requireAuth(request);
  const isAdmin = auth.token.email === ADMIN_EMAIL;

  const user = await admin.auth().getUser(auth.uid);
  const existingClaims = user.customClaims || {};
  if (existingClaims.admin !== isAdmin) {
    await admin.auth().setCustomUserClaims(auth.uid, { ...existingClaims, admin: isAdmin });
  }

  // Firestore's copy of isAdmin is a display-only badge from here on (see
  // firestore.rules -- only this Admin SDK write, never a client write, can
  // set it). Keep it in sync so profile/admin-list UIs still show correctly.
  await admin.firestore().collection("users").doc(auth.uid).set({ isAdmin }, { merge: true });

  return { admin: isAdmin };
});

exports.setUserAdminClaim = onCall(async (request) => {
  const auth = requireAuth(request);
  if (auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Only an admin can grant or revoke admin access.");
  }

  const targetUid = request.data?.targetUid;
  const isAdmin = request.data?.isAdmin === true;
  if (typeof targetUid !== "string" || !targetUid) {
    throw new HttpsError("invalid-argument", "A valid targetUid is required.");
  }

  const targetUser = await admin.auth().getUser(targetUid);
  if (targetUser.email === ADMIN_EMAIL && !isAdmin) {
    throw new HttpsError("failed-precondition", "Cannot revoke admin from the primary admin account.");
  }

  const existingClaims = targetUser.customClaims || {};
  await admin.auth().setCustomUserClaims(targetUid, { ...existingClaims, admin: isAdmin });
  await admin.firestore().collection("users").doc(targetUid).set({ isAdmin }, { merge: true });

  return { ok: true, targetUid, admin: isAdmin };
});

// ---------------------------------------------------------------------------
// Friend graph (HAL-07)
//
// sendFriendRequest/acceptFriendRequest/rejectFriendRequest used to write
// directly to `users/<other-uid>` from the client -- both in RTDB and
// Firestore -- which the security rules correctly reject (a user may only
// write their own node), so these calls always failed. Firestore is now the
// single source of truth for the social graph (the client already queries it
// for search); these callables validate the caller server-side via the
// Admin SDK, which bypasses rules, and are the only path allowed to touch
// another user's friend-request/friends fields.
// ---------------------------------------------------------------------------

exports.sendFriendRequest = onCall(async (request) => {
  const auth = requireAuth(request);
  const fromUid = auth.uid;
  const toUid = request.data?.toUid;
  if (typeof toUid !== "string" || !toUid || toUid === fromUid) {
    throw new HttpsError("invalid-argument", "A valid target user id is required.");
  }

  const db = admin.firestore();
  const batch = db.batch();
  batch.set(db.collection("users").doc(toUid), {
    pendingFriendRequests: admin.firestore.FieldValue.arrayUnion(fromUid),
  }, { merge: true });
  batch.set(db.collection("users").doc(fromUid), {
    sentFriendRequests: admin.firestore.FieldValue.arrayUnion(toUid),
  }, { merge: true });
  await batch.commit();

  return { ok: true };
});

exports.respondToFriendRequest = onCall(async (request) => {
  const auth = requireAuth(request);
  const myUid = auth.uid;
  const fromUid = request.data?.fromUid;
  const accept = request.data?.accept === true;
  if (typeof fromUid !== "string" || !fromUid) {
    throw new HttpsError("invalid-argument", "A valid requester user id is required.");
  }

  const db = admin.firestore();
  const batch = db.batch();
  const myUpdate = {
    pendingFriendRequests: admin.firestore.FieldValue.arrayRemove(fromUid),
  };
  const theirUpdate = {
    sentFriendRequests: admin.firestore.FieldValue.arrayRemove(myUid),
  };
  if (accept) {
    myUpdate.friends = admin.firestore.FieldValue.arrayUnion(fromUid);
    theirUpdate.friends = admin.firestore.FieldValue.arrayUnion(myUid);
  }
  batch.set(db.collection("users").doc(myUid), myUpdate, { merge: true });
  batch.set(db.collection("users").doc(fromUid), theirUpdate, { merge: true });
  await batch.commit();

  return { ok: true, accepted: accept };
});

// Daily rewards used to trust local SharedPreferences for both the streak and
// the currency credit, allowing a reinstall or another device to claim the
// same day again. Keep the calendar state and balance update in one Firestore
// transaction, using the app's Cairo calendar day.
exports.claimDailyReward = onCall(async (request) => {
  const auth = requireAuth(request);
  const today = cairoDateKey();
  const userRef = admin.firestore().collection("users").doc(auth.uid);
  let result;

  await admin.firestore().runTransaction(async (transaction) => {
    const user = await transaction.get(userRef);
    if (!user.exists) {
      throw new HttpsError("not-found", "User profile not found.");
    }
    const data = user.data() || {};
    const daily = data.dailyReward || {};
    if (daily.lastClaimDate === today) {
      throw new HttpsError("already-exists", "Today's reward has already been claimed.");
    }
    const { streak, reward } = dailyRewardStatus(daily, today);
    transaction.update(userRef, {
      coins: (Number.isFinite(data.coins) ? data.coins : 0) + reward.coins,
      diamonds: (Number.isFinite(data.diamonds) ? data.diamonds : 0) + reward.diamonds,
      dailyReward: { lastClaimDate: today, streak },
    });
    result = { streak, coins: reward.coins, diamonds: reward.diamonds, date: today };
  });

  return { ok: true, ...result };
});

exports.getDailyRewardStatus = onCall(async (request) => {
  const auth = requireAuth(request);
  const user = await admin.firestore().collection("users").doc(auth.uid).get();
  if (!user.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }
  const { streak, claimedToday, reward } = dailyRewardStatus(user.get("dailyReward") || {}, cairoDateKey());
  return { streak, isClaimableToday: !claimedToday, coins: reward.coins, diamonds: reward.diamonds };
});

// Authoritative match actions. The secret deck is never written to the
// client-readable match tree; a public projection and participant-only hands
// are persisted after the engine has validated the caller and transition.
exports.submitMatchAction = onCall(async (request) => {
  const auth = requireAuth(request);
  const roomId = requireRoomId(request.data?.roomId);
  const action = request.data?.action;
  if (!action || typeof action.type !== "string") {
    throw new HttpsError("invalid-argument", "A match action is required.");
  }
  const db = admin.database();
  const [matchSnap, handsSnap, secretSnap] = await Promise.all([
    db.ref(`matches/${roomId}`).once("value"),
    db.ref(`matchHands/${roomId}`).once("value"),
    db.ref(`matchSecrets/${roomId}`).once("value"),
  ]);
  const persisted = matchSnap.val();
  if (!persisted || persisted.players?.[auth.uid] !== true) {
    throw new HttpsError("permission-denied", "You are not a participant in this match.");
  }
  const state = { ...persisted, handCards: handsSnap.val() || {} };
  const secret = secretSnap.val() || {};
  let nextState;
  let nextDeck = secret.deck || [];
  try {
    switch (action.type) {
      case "startRound": {
        ({ state: nextState, deck: nextDeck } = matchEngine.startRound(
          state,
          auth.uid,
          (upperBound) => crypto.randomInt(upperBound),
        ));
        break;
      }
      case "cut": {
        ({ state: nextState, deck: nextDeck } = matchEngine.cut(state, nextDeck, auth.uid, action.position));
        break;
      }
      case "dealInitial": {
        ({ state: nextState, deck: nextDeck } = matchEngine.deal(state, nextDeck, auth.uid, { initial: true }));
        break;
      }
      case "dealSubsequent": {
        ({ state: nextState, deck: nextDeck } = matchEngine.deal(state, nextDeck, auth.uid, { initial: false }));
        break;
      }
      case "playCard": {
        nextState = matchEngine.playCard(state, auth.uid, action.card);
        break;
      }
      default:
        throw new HttpsError("invalid-argument", "Unsupported match action.");
    }
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("failed-precondition", error.message || "Action is invalid.");
  }

  const publicState = { ...nextState };
  delete publicState.handCards;
  await db.ref().update({
    [`matches/${roomId}`]: publicState,
    [`matchHands/${roomId}`]: nextState.handCards,
    [`matchSecrets/${roomId}/deck`]: nextDeck,
  });
  return { ok: true, roomId };
});

// ---------------------------------------------------------------------------
// Room lifecycle
//
// Room creation and seat selection used to be direct RTDB writes. That let
// any signed-in user overwrite a waiting room, and two joiners could claim
// the same seat from stale reads. These callables are the only lifecycle
// writers; the Admin SDK performs the matching match and lobby-index update.
// The actual in-match state transition remains client-hosted for now and is
// migrated separately.
// ---------------------------------------------------------------------------

exports.createRoom = onCall(async (request) => {
  const auth = requireAuth(request);
  const mode = request.data?.mode;
  const maxPoints = request.data?.maxPoints;
  const timerDurationSeconds = request.data?.timerDurationSeconds;
  const isPublic = request.data?.isPublic;
  if (!ROOM_MODES.has(mode) || !ROOM_POINTS.has(maxPoints) ||
      !ROOM_TIMERS.has(timerDurationSeconds) || typeof isPublic !== "boolean") {
    throw new HttpsError("invalid-argument", "Invalid room configuration.");
  }

  const displayName = optionalText(request.data?.displayName, "displayName", 64) ||
    optionalText(auth.token.name, "displayName", 64) || "Player";
  const cardBackId = optionalText(request.data?.cardBackId, "cardBackId", 64);
  const avatarUrl = optionalText(request.data?.avatarUrl, "avatarUrl", 2048);
  const db = admin.database();

  for (let attempt = 0; attempt < 5; attempt++) {
    const roomId = createRoomId();
    const matchRef = db.ref(`matches/${roomId}`);
    const now = new Date();
    const match = {
      id: roomId,
      mode,
      maxPoints,
      playerIds: [auth.uid, "waiting_1", "waiting_2", "waiting_3"],
      players: { [auth.uid]: true },
      playerNames: { [auth.uid]: displayName },
      playerSkins: { [auth.uid]: cardBackId },
      playerAvatars: { [auth.uid]: avatarUrl },
      dealerIndex: 0,
      currentTurnIndex: 1,
      phase: "waitingForPlayers",
      timerDurationSeconds,
      isPublic,
      createdAt: admin.database.ServerValue.TIMESTAMP,
      // A room that is never joined must not remain in the public index forever.
      expireAt: new Date(now.getTime() + 30 * 60 * 1000).toISOString(),
    };
    const created = await matchRef.transaction((current) => current === null ? match : undefined);
    if (!created.committed) continue;

    await db.ref().update({ [`rooms/${roomId}`]: roomSummary(match) });
    return { roomId, match };
  }

  throw new HttpsError("aborted", "Could not allocate a room id. Please retry.");
});

exports.joinRoom = onCall(async (request) => {
  const auth = requireAuth(request);
  const roomId = requireRoomId(request.data?.roomId);
  const displayName = optionalText(request.data?.displayName, "displayName", 64) ||
    optionalText(auth.token.name, "displayName", 64) || "Player";
  const cardBackId = optionalText(request.data?.cardBackId, "cardBackId", 64);
  const avatarUrl = optionalText(request.data?.avatarUrl, "avatarUrl", 2048);
  const matchRef = admin.database().ref(`matches/${roomId}`);
  let failure;
  let seatIndex = -1;
  let alreadyJoined = false;

  const result = await matchRef.transaction((current) => {
    if (!current) {
      failure = "not-found";
      return;
    }
    if (current.phase !== "waitingForPlayers") {
      failure = "failed-precondition";
      return;
    }
    if (current.expireAt && Date.parse(current.expireAt) <= Date.now()) {
      failure = "expired";
      return;
    }
    if (!Array.isArray(current.playerIds) || current.playerIds.length !== 4) {
      failure = "invalid-state";
      return;
    }
    const existingIndex = current.playerIds.indexOf(auth.uid);
    if (existingIndex !== -1) {
      alreadyJoined = true;
      seatIndex = existingIndex;
      return current;
    }
    seatIndex = (typeof current.playerIds[2] === "string" && current.playerIds[2].startsWith("waiting_")) ? 2 : current.playerIds.findIndex((id) =>
      typeof id === "string" && id.startsWith("waiting_"));
    if (seatIndex === -1) {
      failure = "full";
      return;
    }

    const next = { ...current };
    next.playerIds = [...current.playerIds];
    next.playerIds[seatIndex] = auth.uid;
    next.players = { ...(current.players || {}), [auth.uid]: true };
    next.playerNames = { ...(current.playerNames || {}), [auth.uid]: displayName };
    next.playerSkins = { ...(current.playerSkins || {}), [auth.uid]: cardBackId };
    next.playerAvatars = { ...(current.playerAvatars || {}), [auth.uid]: avatarUrl };
    return next;
  });

  if (!result.committed) {
    const messages = {
      "not-found": ["not-found", "Room not found."],
      expired: ["failed-precondition", "Room has expired."],
      full: ["failed-precondition", "Room is full."],
      "invalid-state": ["failed-precondition", "Room is invalid."],
      "failed-precondition": ["failed-precondition", "Room is no longer accepting players."],
    };
    const [code, message] = messages[failure] || ["aborted", "Room changed. Please retry."];
    throw new HttpsError(code, message);
  }

  const match = await refreshRoomIndex(roomId);
  // An invite is a one-time prompt, not a permanent room subscription. The
  // Admin SDK owns this cleanup because clients cannot write invite entries.
  await admin.firestore().collection("users").doc(auth.uid).update({
    [`friendInvites.${roomId}`]: admin.firestore.FieldValue.delete(),
  }).catch(() => null);
  return { roomId, match, seatIndex, alreadyJoined };
});

// A match invitation used to be a direct client write to
// users/<recipient>/friendInvites. That allowed every signed-in user to
// impersonate senders or delete someone else's invitations. Verify the
// caller, friendship, and joinable room before writing the recipient's
// invitation through the Admin SDK.
exports.sendRoomInvite = onCall(async (request) => {
  const auth = requireAuth(request);
  const roomId = requireRoomId(request.data?.roomId);
  const toUid = request.data?.toUid;
  if (typeof toUid !== "string" || !toUid || toUid === auth.uid) {
    throw new HttpsError("invalid-argument", "A valid recipient is required.");
  }

  const [matchSnap, senderSnap] = await Promise.all([
    admin.database().ref(`matches/${roomId}`).once("value"),
    admin.firestore().collection("users").doc(auth.uid).get(),
  ]);
  const match = matchSnap.val();
  if (!match || match.phase !== "waitingForPlayers" ||
      !match.players || match.players[auth.uid] !== true) {
    throw new HttpsError("failed-precondition", "This room is not accepting invitations.");
  }
  if (match.expireAt && Date.parse(match.expireAt) <= Date.now()) {
    throw new HttpsError("failed-precondition", "Room has expired.");
  }
  if (!Array.isArray(match.playerIds) || match.playerIds.includes(toUid)) {
    throw new HttpsError("failed-precondition", "Recipient cannot join this room.");
  }

  const friends = senderSnap.exists ? senderSnap.get("friends") : [];
  if (!Array.isArray(friends) || !friends.includes(toUid)) {
    throw new HttpsError("permission-denied", "You can only invite a friend.");
  }
  const displayName = optionalText(senderSnap.exists ? senderSnap.get("displayName") : auth.token.name,
    "displayName", 64) || "Player";
  await admin.firestore().collection("users").doc(toUid).set({
    friendInvites: { [roomId]: displayName },
  }, { merge: true });
  return { ok: true, roomId };
});

exports.refreshRoomIndex = onCall(async (request) => {
  const auth = requireAuth(request);
  const roomId = requireRoomId(request.data?.roomId);
  const match = await admin.database().ref(`matches/${roomId}`).once("value");
  if (!match.exists()) {
    throw new HttpsError("not-found", "Room not found.");
  }
  if (match.child(`players/${auth.uid}`).val() !== true) {
    throw new HttpsError("permission-denied", "You are not a participant in this room.");
  }
  await refreshRoomIndex(roomId);
  return { ok: true, roomId };
});

exports.deleteRoom = onCall(async (request) => {
  const auth = requireAuth(request);
  if (auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Only an admin can delete a room.");
  }
  const roomId = requireRoomId(request.data?.roomId);
  await admin.database().ref().update({
    [`matches/${roomId}`]: null,
    [`matchHands/${roomId}`]: null,
    [`rooms/${roomId}`]: null,
  });
  return { ok: true, roomId };
});

// Server-owned expiry cleanup replaces the old best-effort client-side
// deletion. It removes all room records together even when no client is open.
// Expiry creation/updates are fully migrated with the game loop in a later
// step; this function is deliberately the only deletion path for expiry.
exports.cleanupExpiredRooms = onSchedule("every 24 hours", async () => {
  const db = admin.database();
  const now = new Date().toISOString();
  const expired = await db.ref("rooms").orderByChild("expireAt").endAt(now).once("value");
  const updates = {};
  expired.forEach((child) => {
    const roomId = child.key;
    if (!roomId || !ROOM_ID_PATTERN.test(roomId)) return;
    updates[`matches/${roomId}`] = null;
    updates[`matchHands/${roomId}`] = null;
    updates[`rooms/${roomId}`] = null;
  });
  if (Object.keys(updates).length > 0) await db.ref().update(updates);
});

// ---------------------------------------------------------------------------
// Match helpers (HAL-09 / HAL-10)
//
// Both were unauthenticated onRequest endpoints: anyone on the internet
// could call them. dealCards also returned `remaining` -- the entire
// shuffled deck in order -- to whoever called it. They're onCall now (the
// callable framework itself requires a valid ID token), Math.random()'s
// shuffle is replaced with crypto.randomInt, and dealCards no longer returns
// the deck or other players' hands, only the caller's own hand plus the
// public board.
//
// Neither function is wired into the live match flow today -- the app runs
// the actual game via GameEngine client-side (see game_engine.dart), and
// whichever peer is host writes the result straight to the database. Making
// these two functions the real, authoritative dealer/referee is a larger
// architectural change (see the "server-authoritative match loop" item in
// the revival plan); this pass only closes the concrete leak and auth hole
// in the functions as they exist.
// ---------------------------------------------------------------------------

exports.validateMove = onCall(async (request) => {
  const auth = requireAuth(request);
  const matchId = request.data?.matchId;
  const playedCard = request.data?.playedCard;
  if (typeof matchId !== "string" || !matchId || !playedCard || typeof playedCard.rank !== "string") {
    throw new HttpsError("invalid-argument", "matchId and playedCard are required.");
  }

  const matchSnap = await admin.database().ref(`matches/${matchId}`).once("value");
  const match = matchSnap.val();
  if (!match) {
    throw new HttpsError("not-found", "Match not found.");
  }
  if (!match.players || !match.players[auth.uid]) {
    throw new HttpsError("permission-denied", "You are not a participant in this match.");
  }

  const board = Array.isArray(match.board) ? match.board : [];
  if (board.length === 0) {
    return { valid: true, captured: [] };
  }

  // Mirrors GameEngineUtils.calculateCapture exactly: a played card captures
  // the whole board only when its rank matches the current top card's rank.
  // (The previous copy of this function also captured on any JACK or on the
  // seven of diamonds, and had a placeholder Tafweet branch -- neither rule
  // exists in the real engine, so both are gone; Dart is the one authority
  // for the ruleset, per UNI-06.)
  const topCard = board[board.length - 1];
  const isMatch = playedCard.rank === topCard.rank;
  const captured = isMatch ? [...board, playedCard] : [];

  return { valid: true, captured, isBasra: isMatch && board.length > 0 };
});

exports.dealCards = onCall(async (request) => {
  const auth = requireAuth(request);
  const matchId = request.data?.matchId;
  const isInitialDeal = request.data?.isInitialDeal === true;
  if (typeof matchId !== "string" || !matchId) {
    throw new HttpsError("invalid-argument", "matchId is required.");
  }

  const matchSnap = await admin.database().ref(`matches/${matchId}`).once("value");
  const match = matchSnap.val();
  if (!match) {
    throw new HttpsError("not-found", "Match not found.");
  }
  const playerIds = Array.isArray(match.playerIds) ? match.playerIds : [];
  if (playerIds.length !== 4 || !playerIds.includes(auth.uid)) {
    throw new HttpsError("permission-denied", "You are not a participant in this 4-player match.");
  }

  const suits = ["HEARTS", "DIAMONDS", "CLUBS", "SPADES"];
  const ranks = ["TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "JACK", "QUEEN", "KING", "ACE"];

  let deck = [];
  if (isInitialDeal) {
    suits.forEach((s) => ranks.forEach((r) => deck.push({ id: `${r}_${s}`, rank: r, suit: s })));
    for (let i = deck.length - 1; i > 0; i--) {
      const j = crypto.randomInt(i + 1);
      [deck[i], deck[j]] = [deck[j], deck[i]];
    }
  } else {
    // Continuing a deal needs the deck the initial deal left behind, which
    // this stateless function never persisted anywhere -- there is nothing
    // authoritative to resume from until dealing is actually wired into the
    // match flow server-side.
    throw new HttpsError("failed-precondition", "Non-initial deals are not supported yet.");
  }

  const hands = {};
  playerIds.forEach((id, index) => {
    hands[id] = deck.slice(4 + index * 4, 4 + 4 + index * 4);
  });
  const board = deck.slice(0, 4);

  return { board, hand: hands[auth.uid] };
});
