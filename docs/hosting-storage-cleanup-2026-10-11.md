# Approved one-time Hosting archive cleanup

The gameplay patch `4af01f46` passed CI tests and the release web build, but
Hosting run 38120033132 failed creating a version with HTTP 429:
`RESOURCE_EXHAUSTED` / Hosting storage quota exceeded. The user approved deleting
old website builds while preserving the live version and two rollback versions.

The cleanup uses the existing GitHub Actions Firebase deployment service account
in memory, never a new key or an exposed endpoint. It operates only on
`halabessa-card-game1` Hosting resources. Authentication, databases, accounts,
matches, balances and Supabase are outside its request paths.

`scripts/cleanup-hosting-archives.mjs` defaults to read-only. Applying requires
the explicit `--apply-approved-halabessa-archives` argument. It lists the live
release history and all active channels, protects the actual live build plus
two distinct available rollback versions and all currently serving preview
versions, verifies retained content, then deletes only older FINALIZED versions
from that live history. It rechecks channel releases before every deletion and
stops if any change. Deleted archive content is not recoverable as a Hosting
rollback; code remains in Git and can be rebuilt. Release metadata is retained
by Firebase. No retained version or live release is intentionally modified.

The Actions cleanup step runs only for the maintenance commit whose exact
message is `Cleanup approved archived Firebase Hosting builds`; ordinary future
commits skip it. This is not permission for recurring automatic cleanup or
changing project billing. The normal verified Hosting deployment follows it.
Ten isolated tests cover scope validation, dry-run, retention, duplicate
releases/rollbacks, preview protection, pagination, unavailable retained content
and interrupted cleanup. All pass locally.

Firebase can reclaim deleted archive content asynchronously (up to 24 hours),
so acceptance of deletion is not proof that a new deployment will immediately
fit. The deployment run must be checked separately.

References: [Hosting resource management](https://firebase.google.com/docs/hosting/manage-hosting-resources)
and [version deletion API](https://firebase.google.com/docs/reference/hosting/rest/v1beta1/sites.versions/delete).
