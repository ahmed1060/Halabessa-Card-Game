import type { Card, MatchState } from './match_engine.ts';

export type ShownCard = { card: Card; eventId: string; hand: number };
type Usage = { shows: number; slams: number; shown: ShownCard[] };
export type CardFeatures = { scope: string; players: Record<string, Usage>;
  lastSlam?: { cardId: string; ownerUid: string; eventId: string } };
const key = (card: Card) => `${card.suit}_${card.rank}`;
const scope = (state: MatchState) => `${state.matchSequence ?? 0}:${state.roundCount ?? 1}`;

/** Metadata only. Never mutate the supplied cards, deck, board or turn. */
export function cardFeatures(state: MatchState): CardFeatures {
  const prior = state.cardFeatures as CardFeatures | undefined;
  if (!prior || prior.scope !== scope(state)) return { scope: scope(state), players: {} };
  return structuredClone(prior);
}

function participant(state: MatchState, uid: string) {
  if (!(state.playerIds ?? []).includes(uid) || /^(bot_|waiting_)/.test(uid)) {
    throw new Error('human_participant_required');
  }
  if (state.roomClosed === true || state.phase !== 'playing') throw new Error('show_not_ready');
}
function owned(state: MatchState, uid: string, value: unknown): Card {
  const supplied = value as Partial<Card> | null;
  const card = (state.handCards?.[uid] ?? []).find(c =>
    c.suit === supplied?.suit && c.rank === supplied?.rank);
  if (!card) throw new Error('card_not_owned');
  return { suit: card.suit, rank: card.rank };
}
function usage(features: CardFeatures, uid: string): Usage {
  if (!Object.hasOwn(features.players, uid)) {
    features.players = {...features.players, [uid]: { shows: 0, slams: 0, shown: [] }};
  }
  return features.players[uid];
}

export function showCard(state: MatchState, uid: string, value: unknown): MatchState {
  participant(state, uid);
  const card = owned(state, uid, value);
  const features = cardFeatures(state), own = usage(features, uid);
  // The same visible card is idempotent, not a fourth displayed copy or sound.
  if (own.shown.some(item => item.hand === Number(state.handInRound ?? 1) && key(item.card) === key(card))) return state;
  if (own.shows >= 3) throw new Error('reveal_limit_reached');
  own.shows++;
  own.shown.push({ card, hand: Number(state.handInRound ?? 1),
    eventId: `${features.scope}:${uid}:show:${own.shows}` });
  return { ...state, cardFeatures: features };
}

export function assertGestureSlam(state: MatchState, uid: string, value: unknown) {
  participant(state, uid); owned(state, uid, value);
  if (usage(cardFeatures(state), uid).slams >= 3) throw new Error('slam_limit_reached');
}

/** Called only AFTER the unchanged legal-play validator accepts the move. */
export function recordGestureSlam(before: MatchState, after: MatchState, uid: string, value: unknown): MatchState {
  const card = owned(before, uid, value);
  const features = cardFeatures(after), own = usage(features, uid);
  own.slams++;
  features.lastSlam = { cardId: key(card), ownerUid: uid,
    eventId: `${features.scope}:${uid}:slam:${own.slams}` };
  return { ...after, cardFeatures: features };
}

/** Drop only displayed copies whose original is no longer held. Usage survives
 * all three hands, reconnects and turns, and resets only for a new deck cycle. */
export function reconcileCardFeatures(state: MatchState): MatchState {
  if (!state.cardFeatures) return state;
  const features = cardFeatures(state);
  for (const uid of Object.keys(features.players)) {
    if (!(state.playerIds ?? []).includes(uid)) { delete features.players[uid]; continue; }
    const hand = state.handCards?.[uid] ?? [];
    features.players[uid].shown = features.players[uid].shown.filter(item =>
      item.hand === Number(state.handInRound ?? 1) && hand.some(card => key(card) === key(item.card)));
  }
  if (features.lastSlam && !(state.playerIds ?? []).includes(features.lastSlam.ownerUid)) delete features.lastSlam;
  return { ...state, cardFeatures: features };
}
