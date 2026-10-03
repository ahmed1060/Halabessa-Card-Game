# Personal iPhone testing from Windows

The iOS workflow builds on GitHub's macOS runner and packages
`Halabessa-unsigned.ipa` inside the `halabessa-ios-unsigned-ipa` artifact.
The original `ios-build` artifact remains available for diagnostics.

The IPA is **unsigned**. Opening it on an iPhone does not install it. It is not
a TestFlight/App Store submission, and successful compilation does not prove
successful installation or gameplay on a physical device.

## Download and install

1. Open the latest successful **Flutter iOS Build** run in GitHub Actions.
2. Download **halabessa-ios-unsigned-ipa** under Artifacts. Extract the downloaded
   ZIP on Windows to obtain `Halabessa-unsigned.ipa`. Keep the IPA itself intact.
3. If you choose third-party personal signing, download Sideloadly only from
   <https://sideloadly.io/> and follow its official Windows prerequisites.
   Review its credential handling before using it.
4. Connect your iPhone by USB, unlock it, and approve **Trust This Computer**.
5. Select the IPA and your device in Sideloadly. Authenticate with your own Apple
   Account in that tool. Never send your password or verification code in chat
   or commit them to the repository. Do not buy shared signing certificates.
6. Complete signing/installation. If requested, trust your developer identity
   under **Settings > General > VPN & Device Management**. Enable **Developer
   Mode** under **Settings > Privacy & Security** when required; this may restart
   the device.

Free-account signing lasts seven days; refresh/reinstall with the same account
and bundle identifier to avoid losing local data. Free accounts have device,
app-ID and installed-app limits. Some capabilities are unavailable. In
particular, this project includes Sign in with Apple: do not assume that it
works with free personal signing. Use guest play for the first device test.
Changing the bundle identifier during signing may also affect configured
authentication providers.

If installation fails, share the error text with account details redacted.
Never disable antivirus protections to install a downloaded file.

## Sources

- Sideloadly Windows support, refresh limits and device setup:
  <https://sideloadly.io/faq.html>
- Apple's free-account limitations:
  <https://developer.apple.com/support/compare-memberships/>

Native installation has not yet been verified on a physical iPhone.
