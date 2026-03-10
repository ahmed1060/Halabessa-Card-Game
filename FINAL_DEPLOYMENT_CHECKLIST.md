# 🚀 Halabessa Final Deployment Checklist

This checklist ensures a smooth transition from development to production. Follow these steps to prepare your builds for release.

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

- [ ] **Web**: `flutter build web --release --base-href "/your-path/"`
- [ ] **Android**: `flutter build apk --release` or `flutter build appbundle --release`
- [ ] **iOS**: `flutter build ios --release`

## 3. Production Environment

- [ ] **Firebase Rules**: Verify that Firestore and Realtime Database rules are locked down for production.
- [ ] **API Keys**: Ensure Google Services files (google-services.json / GoogleService-Info.plist) are using the production project.
- [ ] **Asset Audit**: Check that all images in `assets/images/` are optimized (tinypng.com).

## 4. Final Sanity Checks

- [ ] **Volume Persistence**: Verify that settings are saved between sessions.
- [ ] **Unity Transparency**: Ensure the table background color shows through the Unity layer on Web.
- [ ] **Haptics**: Confirm haptic feedback only triggers when enabled in settings.

## 5. Deployment

- [ ] **GitHub Pages / Firebase Hosting**: Deploy the `build/web` folder.
- [ ] **Play Store / App Store**: Upload the generated AAB/IPA.

Good luck with the launch! 🃏👑
