import test from 'node:test';
import assert from 'node:assert/strict';
import { assignBotDifficulties, chooseBotCard } from '../../supabase/functions/halabessa-api/bot_strategy.ts';
import { advanceMatch, lifecycleCommand, resolveShuffleBotVotes } from '../../supabase/functions/halabessa-api/match_lifecycle.ts';

test('shuffle bots follow human majority and randomize a shared tie ballot', () => {
  const ids = ['a', 'b', 'c', 'bot_4'];
  assert.equal(resolveShuffleBotVotes(ids, {a: true, b: true, c: false, bot_4: false}).bot_4, true);
  assert.equal(resolveShuffleBotVotes(ids, {a: true, b: false, c: false}).bot_4, false);
  for (const [random, choice] of [[() => 0.1, true], [() => 0.9, false]] as const) {
    assert.deepEqual(resolveShuffleBotVotes(['a', 'b', 'bot_3', 'bot_4'], {a: true, b: false}, random),
      {a: true, b: false, bot_3: choice, bot_4: choice});
  }
  assert.equal(resolveShuffleBotVotes(['a', 'bot_2'], {}).bot_2, false);
});

const now = Date.parse('2026-10-05T12:00:00Z');
const base = {playerIds: ['human', 'bot_2', 'bot_3', 'bot_4'], phase: 'rematchVoting',
  phaseStartedAt: new Date(now).toISOString(), rematchVotes: {}, roundCount: 3};

test('shuffle transition records bot ballots only after humans finish', () => {
  const state = {...base, phase: 'shuffleVoting', shuffleVotes: {}};
  assert.throws(() => advanceMatch(state, [], now + 9999), /no_transition_due/);
  const voted = lifecycleCommand('voteShuffle', state, [], 'human', {vote: true}, now + 5000);
  const next = advanceMatch(voted.state, [], now + 5000).state;
  assert.deepEqual(next.shuffleVotes, {human: true, bot_2: true, bot_3: true, bot_4: true});
  assert.equal(next.phase, 'preRoundCut');
});

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
