import test from 'node:test';
import assert from 'node:assert/strict';
import { showCard, cardFeatures, reconcileCardFeatures, assertGestureSlam } from '../../supabase/functions/halabessa-api/card_reveal.ts';
import { executeMatchIntent } from '../../supabase/functions/halabessa-api/match_commands.ts';
import { publicMatchState, matchMirrorUpdates } from '../../supabase/functions/halabessa-api/match_delivery.ts';
import { anonymizeDeletedPlayer, roomReferencesDeletedPlayer } from '../../supabase/functions/halabessa-api/deletion_room_state.ts';
import type { Card, MatchState } from '../../supabase/functions/halabessa-api/match_engine.ts';

const hand: Card[] = ['two', 'three', 'four', 'five'].map(rank => ({ suit: 'clubs', rank }));
const now = Date.parse('2026-10-20T10:00:00Z');
function playing(): MatchState { return { id: 'ABC12345', matchSequence: 2, roundCount: 1,
  handInRound: 1, phase: 'playing', playerIds: ['a','b','c','d'], currentTurnIndex: 0,
  turnStartTime: new Date(now).toISOString(), timerDurationSeconds: 30, mode: 'classic',
  board: [], teamAScore: 0, teamBScore: 0,
  handCards: { a: [...hand], b: hand.map(c => ({ ...c, suit: 'hearts' })), c: [], d: [] } }; }

test('three public shows are independent of legal play, turns, timing and private hand contents', () => {
  let state = playing(); const original = structuredClone(state);
  for (const card of hand.slice(0, 3)) state = showCard(state, 'a', card);
  const { cardFeatures: _, ...unchanged } = state;
  assert.deepEqual(unchanged, original);
  assert.equal(cardFeatures(state).players.a.shown.length, 3);
  assert.throws(() => showCard(state, 'a', hand[3]), /reveal_limit_reached/);
  assert.equal(showCard(state, 'a', hand[0]), state, 'duplicate show consumes no extra use');
  const other = showCard(state, 'b', state.handCards!.b[0]);
  assert.equal(cardFeatures(other).players.b.shows, 1, 'off-turn player has an independent allowance');
  const projected = publicMatchState(other, 3);
  assert.equal(projected.handCards, undefined);
  assert.equal(JSON.stringify(projected).includes('clubs_five'), false);
  assert.deepEqual(cardFeatures(other).players.a.shown.map(c => c.card), hand.slice(0,3));
});
test('only an authenticated human can reveal its own held card in active play', () => {
  const state = playing();
  assert.throws(() => showCard(state, 'outsider', hand[0]), /human_participant_required/);
  assert.throws(() => showCard(state, 'b', hand[0]), /card_not_owned/);
  assert.throws(() => showCard({ ...state, phase: 'roundScoring' }, 'a', hand[0]), /show_not_ready/);
  assert.throws(() => executeMatchIntent('showCard', state, [], 'a', 'b', { card: hand[0] }, now), /invalid_command_actor/);
  assert.deepEqual(state, playing(), 'rejected input never mutates authoritative state');
});

test('reveals reach seated views only, never the lobby or public match mirror', () => {
  const state = showCard(playing(), 'a', hand[0]);
  const updates = matchMirrorUpdates('ABC12345', {state, hands: state.handCards!, version: 3}, value => value);
  assert.equal(updates['matches/ABC12345/cardFeatures'], null);
  assert.equal((updates['rooms/ABC12345'] as any).cardFeatures, undefined);
  const views = updates['matchViews/ABC12345'] as any;
  assert.deepEqual(views.b.state.cardFeatures, state.cardFeatures);
  assert.deepEqual(views.b.hand, state.handCards!.b);
  assert.equal(views.b.state.handCards, undefined);
  assert.equal(views.outsider, undefined);
  assert.equal(views.a.hand.some((card: Card) => card.rank === 'five'), true);
});

test('account deletion removes feature identity without removing another player reveal', () => {
  const original = showCard(showCard({...playing(), protocolVersion: 1}, 'a', hand[0]), 'b', {suit:'hearts',rank:'two'});
  assert.equal(roomReferencesDeletedPlayer(original, 'a'), true);
  const result = anonymizeDeletedPlayer(original, 'a', 'bot_deleted_' + 'a'.repeat(32));
  assert.equal((result.cardFeatures as any).players.a, undefined);
  assert.deepEqual((result.cardFeatures as any).players.b, (original.cardFeatures as any).players.b);
  assert.equal(roomReferencesDeletedPlayer(result, 'a'), false);
  assert.equal((original.cardFeatures as any).players.a.shows, 1);
});
test('shown-card copies reconcile by identity; hand changes do not reset use counts', () => {
  let state = playing(); for (const card of hand.slice(0,3)) state = showCard(state, 'a', card);
  state = reconcileCardFeatures({ ...state, handCards: { ...state.handCards, a: hand.slice(1) } });
  assert.deepEqual(cardFeatures(state).players.a.shown.map(item => item.card), hand.slice(1,3));
  state = reconcileCardFeatures({ ...state, handInRound: 2 });
  assert.equal(cardFeatures(state).players.a.shown.length, 0);
  assert.equal(cardFeatures(state).players.a.shows, 3);
  assert.throws(() => showCard(state, 'a', hand[3]), /reveal_limit_reached/);
  assert.deepEqual(cardFeatures({ ...state, roundCount: 2 }).players, {});
  assert.deepEqual(cardFeatures({ ...state, matchSequence: 3 }).players, {});
});
test('slam allowance is consumed only after legal play and leaves all gameplay outcomes identical', () => {
  let state = showCard(playing(), 'a', hand[0]);
  const before = structuredClone(state);
  assert.throws(() => executeMatchIntent('playCard', state, [], 'b', 'b',
    { card: state.handCards!.b[0], deliveryStyle: 'slam' }, now), /turn/);
  assert.deepEqual(state, before);
  for (let index = 0; index < 3; index++) {
    const card = hand[index];
    const normal = executeMatchIntent('playCard', state, [], 'a', 'a', { card }, now);
    const slam = executeMatchIntent('playCard', state, [], 'a', 'a', { card, deliveryStyle: 'slam' }, now);
    const strip = (value: MatchState) => { const { cardFeatures: _, ...rest } = value; return rest; };
    assert.deepEqual(strip(slam.state), strip(normal.state)); assert.deepEqual(slam.deck, normal.deck);
    assert.equal(cardFeatures(slam.state).players.a.slams, index + 1);
    assert.equal(cardFeatures(slam.state).players.a.shows, 1);
    state = { ...slam.state, phase: 'playing', currentTurnIndex: 0,
      turnStartTime: new Date(now).toISOString() };
  }
  assert.throws(() => assertGestureSlam(state, 'a', hand[3]), /slam_limit_reached/);
  assert.equal(cardFeatures(executeMatchIntent('playCard', state, [], 'a','a', { card: hand[3] }, now).state).players.a.slams, 3);
});
