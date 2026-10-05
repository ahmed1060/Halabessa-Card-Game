import test from 'node:test';
import assert from 'node:assert/strict';
import { assignBotDifficulties, chooseBotCard } from '../../supabase/functions/halabessa-api/bot_strategy.ts';
import { advanceMatch, lifecycleCommand } from '../../supabase/functions/halabessa-api/match_lifecycle.ts';

const now = Date.parse('2026-10-05T12:00:00Z');
const base = {playerIds: ['human', 'bot_2', 'bot_3', 'bot_4'], phase: 'rematchVoting',
  phaseStartedAt: new Date(now).toISOString(), rematchVotes: {}, roundCount: 3};

test('bots cannot decide or close a human voting window', () => {
  assert.throws(() => advanceMatch({...base, rematchVotes: {bot_2: false, bot_3: false, bot_4: false}}, [], now + 9999), /no_transition_due/);
  const yes = lifecycleCommand('voteRematch', base, [], 'human', {vote: true}, now + 5000);
  const next = advanceMatch(yes.state, [], now + 5000).state;
  assert.equal(next.phase, 'preRoundCut');
  assert.equal(next.roundCount, 1);
  assert.equal(next.matchSequence, 1);
});
test('ten second boundary records every unanswered human as No', () => {
  const state = {...base, playerIds: ['human', 'other', 'bot_3', 'bot_4'], rematchVotes: {human: true}};
  assert.throws(() => advanceMatch(state, [], now + 9999), /no_transition_due/);
  const expired = advanceMatch(state, [], now + 10000).state;
  assert.equal(expired.phase, 'matchOver');
  assert.deepEqual(expired.rematchVotes, {human: true, other: false});
});
test('difficulty assignment is retained for a bot throughout its tenure', () => {
  const assigned = assignBotDifficulties(base, () => 0.99);
  assert.deepEqual(assigned.botDifficulties, {bot_2: 'expert', bot_3: 'expert', bot_4: 'expert'});
  assert.deepEqual(assignBotDifficulties(assigned, () => 0).botDifficulties, assigned.botDifficulties);
});
test('each level selects a legal card without reading any other hand', () => {
  const hand = [{suit: 'hearts', rank: 'ace'}, {suit: 'clubs', rank: 'two'}];
  for (const level of ['easy', 'medium', 'hard', 'expert']) {
    const state = {...base, board: [{suit: 'diamonds', rank: 'ace'}],
      botDifficulties: {bot_2: level}, handCards: {bot_2: hand}};
    const honest = chooseBotCard(state, 'bot_2', () => 0.25);
    const poisoned = {...state, handCards: {...state.handCards,
      get human(): never { throw new Error('hidden hand accessed'); }}};
    assert.deepEqual(chooseBotCard(poisoned, 'bot_2', () => 0.25), honest);
    assert.ok(hand.includes(honest));
  }
});
