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
  emit: (record: { event: string; operation: string; total_ms: number; stages: Record<string, number>;
    routing?: Record<string, string> }) => void,
  now: () => number = () => performance.now(),
  routing?: {region: unknown; configuredConnection: unknown},
) {
  const started = now();
  let operation = 'unknown';
  const durations: Record<string, number> = {};
  // Only fixed infrastructure classifications. Even caller-supplied arbitrary
  // labels cannot smuggle an email, token or connection string into logs.
  const region = typeof routing?.region === 'string' &&
    /^(?:ap-(?:northeast-[123]|south-1|southeast-[123])|ca-central-1|eu-(?:central-[12]|west-[123]|north-1)|us-(?:east-[12]|west-[12])|sa-east-1)$/.test(routing.region)
    ? routing.region : 'other';
  const configuredConnection = ['unconfigured', 'invalid', 'direct', 'shared_transaction', 'shared_session', 'other']
    .includes(String(routing?.configuredConnection)) ? String(routing?.configuredConnection) : 'other';
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
        total_ms: Math.round(now() - started), stages: {...durations},
        ...(routing ? {routing: {region, configuredConnection}} : {})});
    },
  };
}
