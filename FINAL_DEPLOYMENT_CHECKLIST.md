# Halabessa deployment and store release checklist

Status: preparation in progress. A green CI build is a compilation check, not
an App Store or Google Play submission artifact. The following store
requirements were checked against official guidance on September 24, 2026.

- Google Play requires Android 16 / API 36 for new app submissions from
  August 31, 2026. See the [target API policy](https://support.google.com/googleplay/android-developer/answer/11926878).
- Google Play requires native code to support 16 KB memory pages. The checked-in
  ARM64 Unity libraries have 16 KB ELF load-segment alignment; the final AAB
  and a 16 KB device still need validation. See the [Android guidance](https://developer.android.com/guide/practices/page-sizes).
- Apple has required Xcode 26 or later with the iOS 26 SDK for App Store
  Connect uploads since April 28, 2026. CI now targets that toolchain, but its
  unsigned `.app` is not a submission artifact. See
  [Apple's requirements](https://developer.apple.com/news/upcoming-requirements/).

## 1. Unity Build (The Engine)
>
> [!IMPORTANT]
> The Unity build must be updated whenever you change C# scripts or Unity assets.

- [ ] **WebGL Build**:
  - Open Unity -> File -> Build Settings.
  - Select **WebGL**.
  - Ensure **Brotli** compression is enabled in Player Settings -> Publishing Settings.
  - Build into `[ProjectRoot]/web/Build`.
  - Verify that `unity.loader.js` and the `Build` folder are correctly updated in the Flutter `web` directory.
- [ ] **Android Build**:
  - Open Unity -> Flutter Unity -> **Export Android**.
  - This updates the `unityLibrary` module in the Flutter project.
- [ ] **iOS Build**:
  - Open Unity -> Flutter Unity -> **Export iOS**.

## 2. Flutter Build (The App)

- [ ] **Web**: confirm the Firebase Hosting GitHub Action succeeds on the
  release commit and smoke-test the deployed game.
- [ ] **Android CI**: confirm the API 36 release-mode APK and its 16 KB
  alignment check pass. This APK currently uses a debug signing key.
- [ ] **Android store build**: keep the upload keystore outside the repository.
  Set `HALABESSA_UPLOAD_KEYSTORE` to its absolute path, plus
  `HALABESSA_UPLOAD_STORE_PASSWORD`, `HALABESSA_UPLOAD_KEY_ALIAS` and
  `HALABESSA_UPLOAD_KEY_PASSWORD`. Set
  `HALABESSA_REQUIRE_UPLOAD_SIGNING=true` when running
  `flutter build appbundle --release` so a missing key fails the build.
  Inspect merged permissions and the Play Console pre-launch report before
  rollout.
- [ ] **iOS CI**: confirm the unsigned Xcode 26 build compiles, including the
  checked-in Unity export and all CocoaPods dependencies.
- [ ] **iOS store build**: configure Apple distribution signing, archive under
  Xcode 26 and test the actual IPA in TestFlight. If the checked-in Unity
  export fails with Xcode 26, regenerate it with a compatible Unity Editor.

## 3. Production Environment

- [ ] **Firebase Rules**: Verify that Firestore and Realtime Database rules are locked down for production.
- [ ] **API Keys**: Ensure Google Services files (google-services.json / GoogleService-Info.plist) are using the production project.
- [ ] **Asset Audit**: Check that all images in `assets/images/` are optimized (tinypng.com).
- [ ] **Privacy**: publish a privacy policy and complete the stores' data
  collection, account deletion, content and age-rating disclosures from the
  actual production build and its SDKs. Validate Apple's privacy manifests
  and required-reason APIs in the final Xcode privacy report.
- [ ] **Account deletion**: implement an in-app deletion flow that removes the
  Firebase identity and associated game data, plus a public web request path
  for Google Play. The app currently creates accounts but has no deletion
  flow. See [Apple's rule](https://developer.apple.com/support/offering-account-deletion-in-your-app)
  and [Google Play's rule](https://support.google.com/googleplay/android-developer/answer/13327111).
- [ ] **Social login**: decide whether iOS will offer Google/Facebook login.
  If it does, add an equivalent privacy-preserving login option under
  [App Review Guideline 4.8](https://developer.apple.com/app-store/review/guidelines/)
  and configure each provider fully. The current Facebook buttons are present
  but the native Facebook app ID/client-token configuration is absent.
- [ ] **Versioning**: increase `version` in `pubspec.yaml` for every store
  release and commit the matching `pubspec.lock`.

## 4. Final Sanity Checks

- [ ] **Volume Persistence**: Verify that settings are saved between sessions.
- [ ] **Unity Transparency**: Ensure the table background color shows through the Unity layer on Web.
- [ ] **Haptics**: Confirm haptic feedback only triggers when enabled in settings.

## 5. Deployment

- [ ] **Firebase Hosting**: deploy the release commit through the existing
  GitHub Action and check the live URL.
- [ ] **Play Store / App Store**: submit only the signed, tested AAB/IPA built
  with the store-required SDKs and complete the store metadata and review
  credentials.

The authoritative multiplayer and Unity-export work still listed in
`docs/technology-modernization.md` must be completed before release.
