export function utcWeekStart(timestamp: string) {
  const date = new Date(timestamp);
  if (!Number.isFinite(date.getTime())) throw new Error('invalid_reward_timestamp');
  date.setUTCHours(0, 0, 0, 0);
  date.setUTCDate(date.getUTCDate() - (date.getUTCDay() + 6) % 7);
  return date.toISOString().slice(0, 10);
}

/** Late settlement from a previous week cannot overwrite a newer period. */
export function weeklyRanking(prior: Record<string, unknown>, week: string,
  reward: { points: number; won: boolean; teamScore: number }) {
  if (typeof prior.week === 'string' && prior.week > week) return null;
  const same = prior.week === week;
  function stat(field: string) {
    if (!same || prior[field] == null) return 0;
    if (!Number.isSafeInteger(prior[field]) || Number(prior[field]) < 0) throw new Error('invalid_weekly_ranking');
    return Number(prior[field]);
  }
  return { week, points: Math.max(0, Math.min(999999, stat('points') + reward.points)),
    wins: stat('wins') + (reward.won ? 1 : 0), losses: stat('losses') + (reward.won ? 0 : 1),
    gamesPlayed: stat('gamesPlayed') + 1, bestScore: Math.max(stat('bestScore'), reward.teamScore) };
}
