export type Card = { suit: string; rank: string };
export type MatchState = Record<string, unknown> & {
  playerIds?: string[];
  handCards?: Record<string, Card[]>;
  board?: Card[];
};

const suits = ["hearts", "diamonds", "clubs", "spades"];
const ranks = ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "jack", "queen", "king", "ace"];

function cardKey(card: Card) {
  return `${card.suit}_${card.rank}`;
}

function assertCard(value: unknown): asserts value is Card {
  const card = value as Card | null;
  if (!card || !suits.includes(card.suit) || !ranks.includes(card.rank)) {
    throw new Error("invalid_card");
  }
}

function numberValue(value: unknown, fallback = 0) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function objectValue<T>(value: unknown): Record<string, T> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, T> : {};
}

export function standardDeck(): Card[] {
  return suits.flatMap((suit) => ranks.map((rank) => ({ suit, rank })));
}

function secureRandomInt(upperBound: number) {
  if (!Number.isInteger(upperBound) || upperBound < 1 || upperBound > 0x100000000) {
    throw new Error("invalid_random_bound");
  }
  const range = 0x100000000;
  const limit = range - (range % upperBound);
  const random = new Uint32Array(1);
  do crypto.getRandomValues(random); while (random[0] >= limit);
  return random[0] % upperBound;
}

function shuffleDeck(deck: Card[]) {
  const next = [...deck];
  for (let index = next.length - 1; index > 0; index -= 1) {
    const swapIndex = secureRandomInt(index + 1);
    [next[index], next[swapIndex]] = [next[swapIndex], next[index]];
  }
  return next;
}

export function startRound(state: MatchState, actorUid: string) {
  const playerIds = state.playerIds;
  if (!Array.isArray(playerIds) || playerIds.length !== 4 || playerIds.some((id) => id.startsWith("waiting_"))) {
    throw new Error("full_match_required");
  }
  if (playerIds[0] !== actorUid) throw new Error("host_required");
  if (!["waitingForPlayers", "shuffleVoting", "rematchVoting", "roundScoring"].includes(String(state.phase))) {
    throw new Error("round_not_ready");
  }
  const deck = shuffleDeck(standardDeck());
  const priorRound = Number.isInteger(state.roundCount) ? state.roundCount as number : 0;
  const firstRound = priorRound < 1;
  const dealerIndex = firstRound ? 0 : (numberValue(state.dealerIndex) + 1) % playerIds.length;
  return {
    state: {
      ...state,
      dealerIndex,
      currentTurnIndex: (dealerIndex + 1) % playerIds.length,
      phase: "preRoundCut",
      roundCount: firstRound ? 1 : priorRound + 1,
      roundsSinceLastShuffle: 0,
      board: [],
      handCards: {},
      harvestStacks: { teamA: [], teamB: [] },
      shuffleVotes: {},
      rematchVotes: {},
      botInjectionVotes: {},
      recentFasha: [],
      cardOwnership: {},
      skippedMatches: {},
      cutLastCard: null,
      lastCaptureTeam: null,
      deckCount: deck.length,
    } as MatchState,
    deck,
  };
}

function cutDeck(deck: Card[], position: unknown) {
  if (!Number.isInteger(position) || (position as number) <= 0 || (position as number) >= deck.length) return [...deck];
  return [...deck.slice(position as number), ...deck.slice(0, position as number)];
}

export function cut(state: MatchState, deck: Card[], actorUid: string, position: unknown) {
  if (state.phase !== "preRoundCut") throw new Error("cut_not_ready");
  const playerIds = state.playerIds;
  if (!Array.isArray(playerIds) || playerIds.length !== 4) throw new Error("four_players_required");
  const dealerIndex = numberValue(state.dealerIndex);
  const cutterIndex = (dealerIndex + playerIds.length - 1) % playerIds.length;
  if (playerIds[cutterIndex] !== actorUid) throw new Error("cutter_required");
  const nextDeck = cutDeck(deck, position);
  return {
    state: {
      ...state,
      deckCount: nextDeck.length,
      phase: "dealingFasha",
      cutLastCard: nextDeck[0] ?? null,
    } as MatchState,
    deck: nextDeck,
  };
}

function draw(deck: Card[]): [Card | null, Card[]] {
  if (deck.length === 0) return [null, deck];
  return [deck[deck.length - 1], deck.slice(0, -1)];
}

export function deal(state: MatchState, deck: Card[], actorUid: string, initial: boolean) {
  const playerIds = state.playerIds;
  if (!Array.isArray(playerIds) || playerIds.length !== 4) throw new Error("four_players_required");
  if (playerIds[numberValue(state.dealerIndex)] !== actorUid) throw new Error("dealer_required");
  if (initial ? state.phase !== "dealingFasha" : state.phase !== "playing") throw new Error("deal_not_ready");
  const hands = objectValue<Card[]>(state.handCards);
  if (!initial && !playerIds.every((id) => (hands[id] ?? []).length === 0)) throw new Error("cards_remain_in_hands");
  const requiredCards = initial ? 20 : 16;
  if (!Array.isArray(deck) || deck.length < requiredCards) throw new Error("insufficient_deck");
  const keys = new Set<string>();
  for (const card of deck) {
    assertCard(card);
    const key = cardKey(card);
    if (keys.has(key)) throw new Error("duplicate_deck_card");
    keys.add(key);
  }
  let remaining = [...deck];
  const board = initial ? [] : [...(Array.isArray(state.board) ? state.board : [])];
  const nextHands: Record<string, Card[]> = { ...hands };
  if (initial) {
    for (let index = 0; index < 4; index += 1) {
      const [card, next] = draw(remaining);
      remaining = next;
      if (card) board.push(card);
    }
  }
  for (const playerId of playerIds) {
    const hand = initial ? [] : [...(nextHands[playerId] ?? [])];
    for (let index = 0; index < 4; index += 1) {
      const [card, next] = draw(remaining);
      remaining = next;
      if (card) hand.push(card);
    }
    nextHands[playerId] = hand;
  }
  return {
    state: {
      ...state,
      board,
      handCards: nextHands,
      deckCount: remaining.length,
      recentFasha: initial ? [...board] : (Array.isArray(state.recentFasha) ? state.recentFasha : []),
      handInRound: initial ? 1 : numberValue(state.handInRound) + 1,
      phase: initial ? "dealingCards" : "playing",
      ...(initial ? {} : { turnStartTime: new Date().toISOString() }),
    } as MatchState,
    deck: remaining,
  };
}

export function playCard(state: MatchState, actorUid: string, value: unknown) {
  assertCard(value);
  const card = value;
  const playerIds = state.playerIds;
  if (state.phase !== "playing") throw new Error("play_not_ready");
  if (!Array.isArray(playerIds) || playerIds[numberValue(state.currentTurnIndex)] !== actorUid) throw new Error("not_your_turn");
  const hands = objectValue<Card[]>(state.handCards);
  const hand = [...(hands[actorUid] ?? [])];
  const cardIndex = hand.findIndex((candidate) => cardKey(candidate) === cardKey(card));
  if (cardIndex < 0) throw new Error("card_not_owned");
  hand.splice(cardIndex, 1);
  const nextHands = { ...hands, [actorUid]: hand };
  const board = [...(Array.isArray(state.board) ? state.board : [])];
  const ownership = objectValue<string>(state.cardOwnership);
  const skipped = objectValue<string[]>(state.skippedMatches);
  const currentTurnIndex = numberValue(state.currentTurnIndex);
  const nextTurn = (currentTurnIndex + 1) % playerIds.length;
  const top = board[board.length - 1];
  if (top && hand.some((candidate) => candidate.rank === top.rank) && card.rank !== top.rank) {
    const skip = `${top.rank}:${ownership[cardKey(top)] ?? "fasha"}`;
    skipped[actorUid] = [...new Set([...(skipped[actorUid] ?? []), skip])];
  }
  if (!top || top.rank !== card.rank) {
    board.push(card);
    ownership[cardKey(card)] = actorUid;
    return {
      ...state,
      board,
      handCards: nextHands,
      cardOwnership: ownership,
      skippedMatches: skipped,
      currentTurnIndex: nextTurn,
      turnStartTime: new Date().toISOString(),
    } as MatchState;
  }

  const team = playerIds.indexOf(actorUid) % 2 === 0 ? "teamA" : "teamB";
  let points = 1;
  const emojis = objectValue<string>(state.playerEmojis);
  if (state.mode === "tafweet") {
    const playerSkips = [...(skipped[actorUid] ?? [])];
    const previousId = playerIds[(currentTurnIndex + playerIds.length - 1) % playerIds.length];
    const rankPrefix = `${card.rank}:`;
    const fasha = playerSkips.includes(`${rankPrefix}fasha`);
    const standard = playerSkips.includes(`${rankPrefix}${previousId}`);
    const double = playerSkips.filter((skip) => skip.startsWith(rankPrefix)).length >= 2 && standard;
    if (fasha) {
      points += 5;
      emojis[actorUid] = "😎";
      skipped[actorUid] = playerSkips.filter((skip) => skip !== `${rankPrefix}fasha`);
    } else if (double) {
      points += 10;
      emojis[actorUid] = "🔥";
      skipped[actorUid] = playerSkips.filter((skip) => !skip.startsWith(rankPrefix));
    } else if (standard) {
      points += 5;
      emojis[actorUid] = "😂";
      skipped[actorUid] = playerSkips.filter((skip) => !skip.startsWith(rankPrefix));
    }
  }
  const harvest = objectValue<unknown[]>(state.harvestStacks);
  harvest[team] = [...(harvest[team] ?? []), { leadingCard: card, capturedCards: board }];
  return {
    ...state,
    board: [],
    handCards: nextHands,
    harvestStacks: harvest,
    skippedMatches: skipped,
    playerEmojis: emojis,
    currentTurnIndex: nextTurn,
    teamAScore: numberValue(state.teamAScore) + (team === "teamA" ? points : 0),
    teamBScore: numberValue(state.teamBScore) + (team === "teamB" ? points : 0),
    lastCaptureTeam: team,
    turnStartTime: new Date().toISOString(),
  } as MatchState;
}
