import assert from "node:assert/strict";
import test from "node:test";
import { createDatabaseRunner, configuredConnectionMode, databaseConnectionString, transactionPoolerConnectionString, probeReadOnlyConnection, withDatabaseGuard } from "../../supabase/functions/halabessa-api/database.ts";

test('verified pooler preserves encoded credentials and TLS without accepting another project', () => {
  const url = new URL(transactionPoolerConnectionString('postgresql://postgres:p%40ss%3A%2F%25@db.jmlipglfgmuyegoroepu.supabase.co:5432/postgres?sslmode=require'));
  assert.equal(url.hostname, 'aws-0-eu-west-2.pooler.supabase.com');
  assert.equal(url.username, 'postgres.jmlipglfgmuyegoroepu');
  assert.equal(url.password, 'p%40ss%3A%2F%25');
  assert.equal(url.port, '6543'); assert.equal(url.searchParams.get('sslmode'), 'require');
  assert.equal(url.searchParams.get('application_name'), 'halabessa-api');
  for (const value of [undefined, 'secret', 'postgres://postgres:secret@db.other.supabase.co/postgres',
    'postgres://admin:secret@db.jmlipglfgmuyegoroepu.supabase.co/postgres',
    'postgres://postgres:secret@db.jmlipglfgmuyegoroepu.supabase.co/postgres?host=other']) {
    assert.throws(() => transactionPoolerConnectionString(value), /^Error: pooler_not_configured$/);
  }
  const enforced = new URL(transactionPoolerConnectionString('postgres://postgres:secret@db.jmlipglfgmuyegoroepu.supabase.co/postgres?sslmode=disable'));
  assert.equal(enforced.searchParams.get('sslmode'), 'require');
});

test('read-only probe rolls back on success and error without replay or commit', async () => {
  for (const fail of [false,true]) {
    const calls: string[] = [];
    const task = probeReadOnlyConnection(async sql => {calls.push(sql); if(fail && sql === 'select 1')throw Error('failure');});
    if(fail) await assert.rejects(task,/failure/); else await task;
    assert.deepEqual(calls, ['begin read only', "set local statement_timeout = '3000ms'", 'select 1', 'rollback']);
  }
});

test('diagnostic clients share the same admission and socket budget as primary work', async () => {
  const purposes: string[] = [];
  const run = createDatabaseRunner(purpose => {purposes.push(purpose); return {async connect(){},async end(){}};});
  await run(async()=>{}); await run(async()=>{},undefined,'background','pooler_probe');
  await run(async()=>{},undefined,'background','direct_probe');
  assert.deepEqual(purposes,['primary','pooler_probe','direct_probe']);
});

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

test('interactive work overtakes queued background work without opening another socket', async () => {
  const gate = deferred<void>(), started = deferred<void>();
  let sockets = 0;
  const order: string[] = [];
  const run = createDatabaseRunner(() => ({
    async connect() {assert.equal(++sockets, 1);}, async end() {sockets--;},
  }));
  const first = run(async () => {started.resolve(); await gate.promise;});
  await started.promise;
  const background = run(async () => {order.push('background');}, undefined, 'background');
  const interactive = run(async () => {order.push('interactive');});
  gate.resolve(); await Promise.all([first, background, interactive]);
  assert.deepEqual(order, ['interactive', 'background']); assert.equal(sockets, 0);
});

test('background admission reserves room for interaction and expires safely', async () => {
  const gate = deferred<void>(), started = deferred<void>();
  let clients = 0;
  const run = createDatabaseRunner(() => {
    clients++; return {async connect() {}, async end() {}};
  }, 3, () => {}, 20);
  const first = run(async () => {started.resolve(); await gate.promise;}); await started.promise;
  const background = run(async () => assert.fail('expired background'), undefined, 'background');
  const expired = assert.rejects(background, /database_busy/);
  await assert.rejects(run(async () => assert.fail(), undefined, 'background'), /database_busy/);
  const foreground = run(async () => assert.fail('expired foreground'));
  const foregroundExpired = assert.rejects(foreground, /database_busy/);
  await expired; await foregroundExpired;
  assert.equal(clients, 1);
  gate.resolve(); await first;
  assert.equal(await run(async () => 'recovered'), 'recovered');
  assert.equal(clients, 2);
});

test('configured pooler classification cannot reveal connection credentials', () => {
  assert.equal(configuredConnectionMode('postgres://private:p%40ss@aws-0-eu-west-2.pooler.supabase.com:6543/postgres'), 'shared_transaction');
  assert.equal(configuredConnectionMode('postgres://private:secret@aws-0-eu-west-2.pooler.supabase.com:5432/postgres'), 'shared_session');
  assert.equal(configuredConnectionMode('postgres://private:secret@db.project.supabase.co:5432/postgres'), 'direct');
  assert.equal(configuredConnectionMode('not-a-url'), 'invalid');
});

test('guard and connection overlap, but no application work precedes guard success', async () => {
  const guard = deferred<void>(), connect = deferred<void>();
  const events: string[] = [];
  const run = createDatabaseRunner(() => ({
    async connect() { events.push('connect'); await connect.promise; },
    async end() { events.push('close'); },
  }));
  const task = withDatabaseGuard(run, async () => {
    events.push('guard'); await guard.promise;
  }, async () => { events.push('work'); return 'allowed'; });
  await Promise.resolve(); await Promise.resolve(); await Promise.resolve();
  assert.ok(events.includes('connect')); assert.ok(events.includes('guard'));
  connect.resolve();
  await Promise.resolve(); await Promise.resolve();
  assert.equal(events.includes('work'), false);
  guard.resolve();
  assert.equal(await task, 'allowed');
  assert.deepEqual(events.slice(-2), ['work', 'close']);
});

test('blocked or unavailable guard closes the socket without query, mutation or replay', async () => {
  for (const code of ['unauthenticated', 'account_guard_unavailable']) {
    const guard = deferred<void>();
    let work = 0, closed = 0;
    const run = createDatabaseRunner(() => ({async connect() {}, async end() { closed++; }}));
    const task = withDatabaseGuard(run, () => guard.promise, async () => { work++; });
    const rejected = assert.rejects(task, new RegExp(code));
    guard.reject(new Error(code)); await rejected;
    assert.equal(work, 0); assert.equal(closed, 1);
    assert.equal(await withDatabaseGuard(run, async () => {}, async () => 'next'), 'next');
    assert.equal(closed, 2);
  }
});

test('connection failure still waits for guard verdict and preserves guard-error precedence', async () => {
  for (const allowed of [false, true]) {
    const guard = deferred<void>();
    let closed = 0, work = 0;
    const run = createDatabaseRunner(() => ({
      async connect() { throw Error('connect_failed'); }, async end() { closed++; },
    }));
    const task = withDatabaseGuard(run, () => guard.promise, async () => { work++; });
    const rejected = assert.rejects(task, allowed ? /connect_failed/ : /unauthenticated/);
    if (allowed) guard.resolve(); else guard.reject(Error('unauthenticated'));
    await rejected;
    assert.equal(closed, 1); assert.equal(work, 0);
  }
});

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

test('an expired queued request never runs or opens a second active socket', async () => {
  let unblock!: () => void;
  let created = 0;
  let open = 0;
  const blocker = new Promise<void>(resolve => { unblock = resolve; });
  const run = createDatabaseRunner(() => {
    created++;
    return {async connect() { open++; assert.equal(open, 1); }, async end() { open--; }};
  }, 8, () => {}, 15);
  const first = run(async () => { await blocker; return 'committed'; });
  let expiredWork = 0;
  await assert.rejects(run(async () => { expiredWork++; }), /database_busy/);
  assert.equal(created, 1);
  assert.equal(expiredWork, 0);
  const third = run(async () => 'after');
  assert.equal(created, 1);
  unblock();
  assert.equal(await first, 'committed');
  assert.equal(await third, 'after');
  assert.equal(created, 2);
  assert.equal(open, 0);
});
