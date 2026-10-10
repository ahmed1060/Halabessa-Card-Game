interface DatabaseClient {
  connect(): Promise<void>;
  end(): Promise<void>;
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
  let tail = Promise.resolve();
  let pending = 0;

  return async function withDatabase<Result>(
    work: (client: Client) => Promise<Result>,
    observe: (stage: string, ms: number) => void = () => {},
  ): Promise<Result> {
    if (pending >= maxPending) throw new Error("database_busy");
    pending += 1;
    const previous = tail;
    let release!: () => void;
    const slot = new Promise<void>((resolve) => { release = resolve; });
    // If a queued caller expires, later slots must still wait for the active
    // transaction. Releasing just `slot` as the tail would permit overlap.
    tail = previous.then(() => slot);
    const queuedAt = performance.now();
    let client: Client | undefined;
    let queueTimer: ReturnType<typeof setTimeout> | undefined;
    try {
      try {
        await Promise.race([previous, new Promise<never>((_, reject) => {
          queueTimer = setTimeout(() => reject(new Error('database_busy')), maxQueueWaitMs);
        })]);
      } finally {
        clearTimeout(queueTimer);
        observe('db_queue', performance.now() - queuedAt);
      }
      client = createClient();
      const connectAt = performance.now();
      try { await client.connect(); }
      finally { observe('db_connect', performance.now() - connectAt); }
      const workAt = performance.now();
      try { return await work(client); }
      finally { observe('db_work', performance.now() - workAt); }
    } finally {
      try {
        // Also clean up when connect or the transaction fails. A close error
        // must not turn an already committed operation into a retryable error.
        const closeAt = performance.now();
        try { if (client) await client.end(); }
        finally { observe('db_close', performance.now() - closeAt); }
      } catch {
        onCloseError();
      } finally {
        pending -= 1;
        release();
      }
    }
  };
}

export function databaseConnectionString(value: string | undefined): string {
  if (!value) throw new Error("server_not_configured");
  const url = new URL(value);
  url.searchParams.set("application_name", "halabessa-api");
  return url.toString();
}
