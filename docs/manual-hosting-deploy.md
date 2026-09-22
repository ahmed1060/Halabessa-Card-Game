# Manual Firebase Hosting deployment

Use this route while GitHub-hosted Actions are unavailable. It builds the web
app locally and deploys only Firebase Hosting; it does not deploy Firebase
Functions or Storage rules.

## First-time setup

1. Install the stable [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) and ensure `flutter doctor` completes without blocking errors.
2. In PowerShell, from the project folder, authenticate the Firebase CLI once:

   ```powershell
   npx --yes firebase-tools@latest login
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
