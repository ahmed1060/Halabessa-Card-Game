const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
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
