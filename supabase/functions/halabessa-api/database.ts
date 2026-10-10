interface DatabaseClient {
  connect(): Promise<void>;
  end(): Promise<void>;
}

/** Overlap an authenticated caller's independent guard and connection setup.
 * No application query or mutation may execute before the guard succeeds.
 * Observe both failures immediately and retain guard-error precedence even if
 * connecting fails first. The supplied runner still owns admission and close.
 */
export async function withDatabaseGuard<Client, Result>(
  run: (work: (client: Client) => Promise<Result>) => Promise<Result>,
  guard: () => Promise<void>,
  work: (client: Client) => Promise<Result>,
): Promise<Result> {
  const checked = Promise.resolve().then(guard).then(
    () => ({ allowed: true as const }),
    (error: unknown) => ({ allowed: false as const, error }),
  );
  try {
    return await run(async client => {
      const result = await checked;
      if (!result.allowed) throw result.error;
      return work(client);
    });
  } catch (error) {
    const result = await checked;
    if (!result.allowed) throw result.error;
    throw error;
  }
}

/** Keep one request at a time per isolate, but no idle database sockets.
 * A pool per Edge isolate is not a project-wide pool: cold starts multiply it,
 * including for OPTIONS/health checks. Create the client only after admission,
 * and close it before allowing the next request to run. Transactions stay on
 * the same client for the entire callback. Never replay a callback on failure.
 */
export function createDatabaseRunner<Client extends DatabaseClient>(
  createClient: () => Client,
  maxPending = 8,
  onCloseError: () => void = () => console.error("halabessa-db: close failed"),
  maxQueueWaitMs = 5_000,
) {
  type Job = {priority: 'interactive' | 'background'; start: () => void; expire: () => void};
  const waiting: Job[] = [];
  let active = false;
  const drain = () => {
    if (active || !waiting.length) return;
    const foreground = waiting.findIndex(job => job.priority === 'interactive');
    const job = waiting.splice(foreground < 0 ? 0 : foreground, 1)[0];
    active = true;
    job.start();
  };

  return async function withDatabase<Result>(
    work: (client: Client) => Promise<Result>,
    observe: (stage: string, ms: number) => void = () => {},
    priority: 'interactive' | 'background' = 'interactive',
  ): Promise<Result> {
    // Background delivery is durable and can wait for cron. Reserve one
    // admission slot for an interactive request instead of filling the queue.
    const limit = priority === 'background' ? Math.max(1, maxPending - 1) : maxPending;
    if (waiting.length + Number(active) >= limit) throw new Error("database_busy");
    const queuedAt = performance.now();
    return new Promise<Result>((resolve, reject) => {
      let queueTimer: ReturnType<typeof setTimeout>;
      const job: Job = {priority, start() {
        clearTimeout(queueTimer);
        observe('db_queue', performance.now() - queuedAt);
        void execute().then(resolve, reject);
      }, expire() {
        const index = waiting.indexOf(job);
        if (index < 0) return;
        waiting.splice(index, 1);
        observe('db_queue', performance.now() - queuedAt);
        reject(Error('database_busy'));
      }};
      async function execute() {
        let client: Client | undefined;
        try {
          client = createClient();
          const connectAt = performance.now();
          try { await client.connect(); }
          finally { observe('db_connect', performance.now() - connectAt); }
          const workAt = performance.now();
          try { return await work(client); }
          finally { observe('db_work', performance.now() - workAt); }
        } finally {
          try {
            const closeAt = performance.now();
            try { if (client) await client.end(); }
            finally { observe('db_close', performance.now() - closeAt); }
          } catch { onCloseError(); }
          finally { active = false; drain(); }
        }
      }
      queueTimer = setTimeout(job.expire, maxQueueWaitMs);
      waiting.push(job);
      drain();
    });
  };
}

export function databaseConnectionString(value: string | undefined): string {
  if (!value) throw new Error("server_not_configured");
  const url = new URL(value);
  url.searchParams.set("application_name", "halabessa-api");
  return url.toString();
}

/** Classification only; never log the URL, hostname, database or credentials.
 * A configured endpoint is not proof of the pooler's live backend behavior.
 */
export function configuredConnectionMode(value: string | undefined) {
  if (!value) return 'unconfigured';
  try {
    const url = new URL(value);
    if (url.hostname.endsWith('.pooler.supabase.com')) {
      return url.port === '6543' ? 'shared_transaction' : 'shared_session';
    }
    if (url.hostname.endsWith('.supabase.co')) return 'direct';
    return 'other';
  } catch { return 'invalid'; }
}
