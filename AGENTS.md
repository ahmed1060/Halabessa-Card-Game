# Repository workflow

- Work in `D:/Projects/Halabessa-Card-Game` on `development`.
- Keep exactly two project branches: `main` and `development`, locally and on
  origin. Do not create feature branches, backup branches, or extra worktrees
  unless the human explicitly changes this policy.
- `main` is the approved release source. Firebase Hosting deploys only from main
  after its release checks pass. Development pushes validate without deploying.
- Keep feature work on development. When ready, open a development-to-main PR;
  merge only with the user's release approval and passing applicable checks.
- Use a merge commit for this long-lived branch pair, keep development after
  merging, and synchronize development with released main without force pushes.
- Preserve local work before changing checkouts or retiring folders. Historical
  source, patches, LFS objects and build data are archived under
  `build/branch-consolidation-2026-10-25/`; do not delete these archives casually.
- The personal `.agents/skills/` directory is preserved locally and excluded via
  `.git/info/exclude`. Read relevant skill instructions when applicable.
- Workflow cleanup must not alter game rules, authoritative state, card counts,
  scoring, timers, user data, sound choices or renderer behavior.
- Use local fixtures/emulators for tests that should not touch production data.
  A Git development branch is not a separate Firebase/Supabase environment.

See `docs/branch-workflow.md` for the release and recovery steps.
