# Edge database connection lifecycle

`halabessa-api` used to eagerly create a one-connection Postgres pool at module
startup. Each serverless isolate had its own pool, even for health checks,
CORS preflight, and unauthenticated requests. Releasing a request's connection
returned it to that isolate's pool rather than closing the socket. Bursts of
isolates could therefore consume the free project's database connection slots.

The function now authenticates first, creates a client only for admitted work,
and closes it in `finally` before returning. It serializes work within each
isolate, admits at most eight pending operations, and never retries a mutation
automatically. Transactions keep the same client throughout the request.
Admission exhaustion and Postgres SQLSTATE `53300` return HTTP 503 with
`Retry-After: 1`. This is overload handling, not a guarantee of unlimited capacity.

`SUPABASE_DB_URL` remains the default, with no new credential required. An optional
server-only `DATABASE_POOLER_URL` can select the project's shared Supavisor
transaction endpoint (port 6543) for larger concurrency. Obtain the exact endpoint
from Supabase's Connect dialog; do not guess its hostname, put its password in
Git, or expose it in Flutter. Using the pooler does not replace request cleanup.
The private `halabessa` schema and Firebase authentication remain unchanged.

Connections are tagged `application_name=halabessa-api`. Inspect them without
reading credentials or player data:

```sql
select application_name, state, count(*)
from pg_stat_activity
where backend_type = 'client backend'
group by application_name, state;
```

Run local regressions with `node --test functions/test/edge_database.test.ts`.
For an intentional, bounded live check, run `node scripts/check-edge-connections.mjs`.
It exercises health/preflight/auth failures, concurrent authenticated reads, and
an invalid command followed by recovery. It deletes its temporary Firebase guest
and reports the exact UID whose Supabase test profile should be removed afterward.
Check Postgres logs for new `53300` errors during the reported test window, and
confirm there are no retained idle `halabessa-api` connections.
