import assert from "node:assert/strict";
import test from "node:test";
import { createDatabaseRunner, databaseConnectionString } from "../../supabase/functions/halabessa-api/database.ts";

test("idle isolates create no clients; completed requests retain no connections", async () => {
  let created = 0;
  let open = 0;
  let peak = 0;
  const run = createDatabaseRunner(() => {
    created += 1;
    return {
      async connect() { open += 1; peak = Math.max(peak, open); },
      async end() { open -= 1; },
    };
  }, 32);
  assert.equal(created, 0);
  await Promise.all(Array.from({ length: 24 }, () => run(async () => {
    assert.equal(open, 1);
    await new Promise((resolve) => setTimeout(resolve, 1));
  })));
  assert.equal(created, 24);
  assert.equal(peak, 1);
  assert.equal(open, 0);
});

test("connect failures and failed transactions close the client and unblock later work", async () => {
  let created = 0;
  const closed: number[] = [];
  let calls = 0;
  const run = createDatabaseRunner(() => {
    const id = ++created;
    return {
      async connect() { if (id === 1) throw new Error("connection_failed"); },
      async end() { closed.push(id); },
    };
  });
  await assert.rejects(run(async () => { calls += 1; }), /connection_failed/);
  await assert.rejects(run(async () => { calls += 1; throw new Error("transaction_failed"); }), /transaction_failed/);
  assert.equal(await run(async () => { calls += 1; return "recovered"; }), "recovered");
  assert.equal(calls, 2); // No replay of a possibly committed mutation.
  assert.deepEqual(closed, [1, 2, 3]);
});

test("a close failure preserves committed results and releases the queue", async () => {
  let closeErrors = 0;
  const run = createDatabaseRunner(() => ({
    async connect() {},
    async end() { throw new Error("socket_closed"); },
  }), 8, () => { closeErrors += 1; });
  assert.equal(await run(async () => "committed"), "committed");
  assert.equal(await run(async () => "next"), "next");
  assert.equal(closeErrors, 2);
});

test("overload rejects before creating a connection; admission recovers", async () => {
  let unblock!: () => void;
  let created = 0;
  const blocker = new Promise<void>((resolve) => { unblock = resolve; });
  const run = createDatabaseRunner(() => {
    created += 1;
    return { async connect() {}, async end() {} };
  }, 1);
  const first = run(async () => await blocker);
  await assert.rejects(run(async () => {}), /database_busy/);
  assert.equal(created, 1);
  unblock();
  await first;
  await run(async () => {});
  assert.equal(created, 2);
});

test("observability preserves the supplied credentials and TLS/pooler settings", () => {
  const source = "postgresql://postgres.project:p%40ss@pooler.example:6543/postgres?sslmode=require";
  const actual = new URL(databaseConnectionString(source));
  assert.equal(actual.username, "postgres.project");
  assert.equal(actual.password, "p%40ss");
  assert.equal(actual.port, "6543");
  assert.equal(actual.searchParams.get("sslmode"), "require");
  assert.equal(actual.searchParams.get("application_name"), "halabessa-api");
  assert.throws(() => databaseConnectionString(undefined), /server_not_configured/);
});
