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
) {
  let tail = Promise.resolve();
  let pending = 0;

  return async function withDatabase<Result>(
    work: (client: Client) => Promise<Result>,
  ): Promise<Result> {
    if (pending >= maxPending) throw new Error("database_busy");
    pending += 1;
    const previous = tail;
    let release!: () => void;
    tail = new Promise<void>((resolve) => { release = resolve; });
    await previous;
    let client: Client | undefined;
    try {
      client = createClient();
      await client.connect();
      return await work(client);
    } finally {
      try {
        // Also clean up when connect or the transaction fails. A close error
        // must not turn an already committed operation into a retryable error.
        if (client) await client.end();
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
