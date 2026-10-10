// Only fixed operation/stage names and durations are observable. Never accept
// payloads, actor IDs, room IDs, credentials or query parameters as labels.
const operations = new Set([
  'getAdminStatus', 'getSocialGraph', 'getPublicProfile', 'queryPublicProfiles',
  'getDailyRewardStatus', 'claimDailyReward', 'getMatchSnapshot',
  'submitMatchCommand', 'createRoom', 'joinRoom', 'settleMatchRewards',
  'bootstrapProfile', 'refreshRoomIndex', 'deleteRoom',
  'sendFriendRequest', 'respondToFriendRequest', 'sendRoomInvite',
  'uploadAsset', 'setUserAdmin', 'requestAccountDeletion',
  'accountDeletionStatus', 'continueAccountDeletion',
  'repairMatchDelivery',
]);
const stages = new Set([
  'jwt', 'deletion_guard', 'db_queue', 'db_connect', 'db_work', 'db_close',
  'profile_sync', 'social_query', 'commit', 'mirror',
]);

export function createRequestTiming(
  emit: (record: { event: string; operation: string; total_ms: number; stages: Record<string, number> }) => void,
  now: () => number = () => performance.now(),
) {
  const started = now();
  let operation = 'unknown';
  const durations: Record<string, number> = {};
  const observe = (stage: string, ms: number) => {
    if (stages.has(stage) && Number.isFinite(ms) && ms >= 0) {
      durations[stage] = (durations[stage] ?? 0) + Math.round(ms);
    }
  };
  return {
    operation(value: unknown) {
      operation = typeof value === 'string' && operations.has(value) ? value : 'unknown';
    },
    observe,
    async measure<T>(stage: string, work: () => Promise<T>): Promise<T> {
      const start = now();
      try { return await work(); }
      finally { observe(stage, now() - start); }
    },
    finish() {
      emit({event: 'halabessa_timing_v1', operation,
        total_ms: Math.round(now() - started), stages: {...durations}});
    },
  };
}
