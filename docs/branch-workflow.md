# Main and development

There is one working folder, `D:/Projects/Halabessa-Card-Game`, and two branches:

| Branch | Use | Website deployment |
| --- | --- | --- |
| development | Ongoing features, fixes and local testing | No deployment |
| main | Approved release source | Deploys after Hosting checks pass |

Keep GitHub Desktop pointed at this root folder and use its branch selector.
The label "Main worktree" means the original folder; normal work in that folder
uses the development branch. Do not create additional feature branches or folders.

## Daily work

Start on development, synchronize it safely, make changes, test, commit and push
to development. Its web validation workflow runs without publishing the game.
Do not commit machine-specific settings, credentials, caches or build outputs.
Avoid switching branches with uncommitted changes.

## Release

1. Finish the feature batch and push development. Freeze that release head while
   its PR checks run, unless the user explicitly chooses a partial release.
2. Open a PR with base main and head development. Run the web, Android and iOS
   checks appropriate to the change, and obtain the user's release approval.
3. Merge using a merge commit. Keep development; do not delete it after merging.
4. Verify main's Hosting deployment and the actual live result. Backend changes
   use the existing controlled release sequence rather than development pushes.
5. Bring development forward to the resulting main. If development has not
   advanced, use a fast-forward. If it has new work, review and merge main into
   development safely; do not reset or force-push away that work.

Example after a completed release with a clean, unchanged development branch:

```powershell
git fetch origin
git switch development
git merge --ff-only origin/main
git push origin development
```

Production Hosting remains restricted to pushes on main. A Git branch alone does
not isolate production Firebase/Supabase data; use existing emulators and fixtures
for local state-mutating tests unless a live test is explicitly authorized.

## Local tools

The shared Flutter SDK and package caches remain under root `build/`.
Local Android tools are under `build/local-android-tools/`; use their JDK through
a process-local JAVA_HOME rather than changing global Java settings.
Unity opens `unity/Halabessa` in this root folder. Local generated settings and
the moved Unity cache are ignored and can be regenerated when needed.

## Preserved older work

The consolidation preserves historical refs in a verified Git bundle, LFS blobs,
source copies, staged/unstaged patches, and archived local/build data under
`build/branch-consolidation-2026-10-25/`. The old root's source was reviewed against
the latest release instead of copied over it. Older local-only design notes and
tests remain in the archive; personal project skills remain available locally.

Restore a specific needed item deliberately. Do not replay an entire old engine,
API file or layout over newer released work. Keep backups until the user approves
any later archive cleanup; they are ignored and must not be published.

## Repository settings

The intended release path uses PRs and checks. Main branch protection is a separate
repository-settings configuration requiring its own concrete review. The unique
check display names are Web validation, Android validation and iOS validation.
When configuring protection, block force pushes/deletion, require the agreed
release checks, and retain development after merging.
