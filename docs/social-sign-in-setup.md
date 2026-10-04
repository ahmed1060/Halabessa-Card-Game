# Social sign-in: verified configuration and owner setup

## Confirmed on 4 October 2026

- Both production Firebase Hosting domains are already in Firebase Auth's authorized domains.
- The committed Android config has a web OAuth client, but no Android-type OAuth entry.
  This is not proof that no Android client exists in the console; download refreshed
  configuration after checking the exact package/certificate pairing.
- The APK workflow currently falls back to a runner-generated debug signing key.
  Registering one build's fingerprint does not register later builds' different keys.
- The iOS Google URL callback scheme differed from GoogleService-Info.plist; corrected.
- Native Facebook app configuration is absent. The Meta App ID is still needed.
- Guest upgrades now link credentials to the existing anonymous UID. An existing-account
  conflict is reported without silently replacing or discarding the guest profile.

## Stable Android Google sign-in

1. Use a persistent keystore that you own and back up privately. Never commit a
   keystore, passwords, service-account key, or Meta app secret to the repository.
2. In GitHub repository settings, add these Actions secrets together:
   `HALABESSA_UPLOAD_KEYSTORE_BASE64`, `HALABESSA_UPLOAD_STORE_PASSWORD`,
   `HALABESSA_UPLOAD_KEY_ALIAS`, `HALABESSA_UPLOAD_KEY_PASSWORD`.
   The first contains the base64-encoded keystore, not a filename. The workflow
   decodes it into a private runner-temporary file only on non-PR runs.
3. Build the APK. Open the **Report actual APK signing certificate for Google
   sign-in setup** job step and copy its public SHA-1/SHA-256 fingerprints.
4. In Firebase Project settings > Your apps > Android app `com.halabessa.game`,
   register the actual certificate fingerprints. This owner-side configuration
   step must be completed before sign-in can be verified.
5. Download refreshed google-services.json, replace the existing Android config,
   rebuild, and test Google sign-in on an installed device.
6. When using Google Play App Signing, register the **Play app-signing** certificate
   too, not just the upload key. A locally installed APK and a Play-delivered APK
   can have different signing certificates.

Existing unsigned/test builds are not claimed to be store-submission ready.
If no secrets are configured, ordinary CI build checks still use debug signing.

## Facebook

Provide the Meta App ID and configure the matching Android/iOS app entries,
Facebook native client token, key hashes/callbacks, and Firebase Auth Facebook
provider. Keep the app secret in the provider's private configuration, never in
Flutter assets or chat. The Facebook button remains visible as requested.

No successful end-to-end Google/Facebook sign-in is claimed from configuration
checks alone. Provider account selection and actual device sign-in still need
verification after owner-controlled setup.

References: [Firebase Android Google sign-in](https://firebase.google.com/docs/auth/android/google-signin),
[Firebase Flutter federated authentication](https://firebase.google.com/docs/auth/flutter/federated-auth).
