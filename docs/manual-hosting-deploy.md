# Manual Firebase Hosting deployment

Use this route while GitHub-hosted Actions are unavailable. It builds the web
app locally and deploys only Firebase Hosting; it does not deploy Firebase
Functions or Storage rules.

## First-time setup

1. Install the stable [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) and ensure `flutter doctor` completes without blocking errors.
2. In PowerShell, from the project folder, authenticate the Firebase CLI once:

   ```powershell
   npx --yes firebase-tools@15.32.1 login
   ```

   Complete the Google sign-in in the browser using the account that owns
   `halabessa-card-game1`. Do not use `firebase login:ci` or store a token in
   the repository.

## Deploy

From the project root, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy-hosting.ps1
```

The command runs `flutter pub get`, creates the release web build, then deploys
only the `hosting` target. The live site remains unchanged if the build or
deployment fails.

## Current index-permission blocker

The main deployment also publishes profile rules and leaderboard indexes before
Hosting. A Hosting-only manual deployment is not a safe workaround for a client
that depends on those rules/indexes.

Run 37600507043 (commit c76a994a) passed server, emulator and Flutter tests, then
failed listing Firestore indexes with HTTP 403. The website was not deployed.
To repair the deployment identity without upgrading Firebase:

1. Open [Google Cloud IAM for this project](https://console.cloud.google.com/iam-admin/iam?project=halabessa-card-game1).
2. Find the **GitHub Actions** service account used by the repository's
   `FIREBASE_SERVICE_ACCOUNT_HALABESSA_CARD_GAME1` secret. Do not edit the human
   owner or Firebase Admin SDK account by mistake. The earlier setup screenshot
   showed `github-action-794963099@halabessa-card-game1.iam.gserviceaccount.com`;
   confirm that it is still the deployment identity.
3. Edit that principal, add **Cloud Datastore Index Admin**
   (`roles/datastore.indexAdmin`), preserve its existing roles and save.
   Do not grant Owner/Editor or generate another private key for this fix.
4. In GitHub Actions, open the latest failed Hosting run and choose
   **Re-run failed jobs** after the permission has propagated.
5. Check that index deployment, dependent rule deployment and Hosting all
   succeed. Wait for required indexes to finish building, then verify rankings
   and private-profile access on the deployed site.

The [Firebase index documentation](https://firebase.google.com/docs/firestore/query-data/indexing)
lists this role for index management. This fixes IAM authorization; it is not
a paid-plan upgrade. No IAM changes were made by the agent.
