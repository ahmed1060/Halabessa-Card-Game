import type { Card, MatchState } from './match_engine.ts';

export const difficulties = ['easy', 'medium', 'hard', 'expert'] as const;
export function assignBotDifficulties(state: MatchState, random = Math.random): MatchState {
  const levels = { ...(state.botDifficulties as Record<string, string> ?? {}) };
  for (const id of state.playerIds ?? []) if (id.startsWith('bot_') && !difficulties.includes(levels[id] as typeof difficulties[number])) {
    levels[id] = difficulties[Math.floor(random() * 4)];
  }
  return { ...state, botDifficulties: levels };
}

/** Deliberately accepts no deck and reads only this bot's hand and public history. */
export function chooseBotCard(state: MatchState, uid: string, random = Math.random): Card {
  const hand = state.handCards?.[uid] ?? [];
  if (!hand.length) throw new Error('empty_hand');
  const board = state.board ?? [];
  const matches = board.length ? hand.filter(c => c.rank === board.at(-1)!.rank) : [];
  const level = (state.botDifficulties as Record<string, string> ?? {})[uid] ?? 'medium';
  if (level === 'easy') {
    const choices = matches.length && random() < 0.6 ? matches : hand;
    return choices[Math.floor(random() * choices.length)];
  }
  if (matches.length) return matches[0];
  const copies = (rank: string) => hand.filter(c => c.rank === rank).length;
  if (level === 'medium') return [...hand].sort((a, b) => copies(b.rank) - copies(a.rank))[0];
  const visible = new Map<string, Card>();
  const record = (card: Card) => visible.set(`${card.suit}_${card.rank}`, card);
  hand.forEach(record); board.forEach(record);
  if (state.cutLastCard) record(state.cutLastCard as Card);
  const captures = state.harvestStacks as Record<string, { leadingCard: Card; capturedCards: Card[] }[]> ?? {};
  Object.values(captures).flat().forEach(c => { record(c.leadingCard); c.capturedCards.forEach(record); });
  const unseen = (rank: string) => Math.max(0, 4 - [...visible.values()].filter(c => c.rank === rank).length);
  const ids = state.playerIds ?? [];
  const seat = ids.indexOf(uid);
  const skips = state.skippedMatches as Record<string, string[]> ?? {};
  const knows = (id: string, rank: string) => (skips[id] ?? []).some(s => s.startsWith(`${rank}:`));
  const score = (card: Card) => {
    const unknown = unseen(card.rank);
    const opponent = knows(ids[(seat + 1) % 4], card.rank);
    if (level === 'hard') return -unknown * 10 - (opponent ? 100 : 0);
    const partner = knows(ids[(seat + 2) % 4], card.rank);
    return (unknown === 0 ? 1200 : 0) - (opponent ? 900 : 0) +
      (partner && !opponent ? 450 : 0) + (copies(card.rank) >= 2 ? 250 : 0) +
      (3 - unknown) * 160 - (unknown >= 2 ? unknown * 40 * (1 + board.length * 0.25) : 0);
  };
  return [...hand].sort((a, b) => score(b) - score(a))[0];
}
