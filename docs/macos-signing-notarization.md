# macOS Signing and Notarization

Petfy can build two macOS package types:

- Local package: ad-hoc signed, useful for development and private testing.
- Signed package: Developer ID signed and optionally notarized for public distribution.

## Local Package

```sh
./pet package-macos
```

This creates:

```text
dist/macos/Petfy-macos-v0.0.1.zip
```

The app is ad-hoc signed. macOS may still show local security warnings because this is not an identified developer build.

## Signed and Notarized Package

Requirements:

- Apple Developer Program membership.
- Developer ID Application certificate installed in Keychain.
- App-specific password or an `xcrun notarytool` keychain profile.
- Xcode command line tools.

Set the Developer ID identity:

```sh
export PETFY_MACOS_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
```

Recommended notarization setup:

```sh
xcrun notarytool store-credentials petfy-notary \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

export PETFY_NOTARY_KEYCHAIN_PROFILE="petfy-notary"
```

Then build:

```sh
./pet package-macos-signed
```

Alternative without a stored profile:

```sh
export PETFY_NOTARY_APPLE_ID="you@example.com"
export PETFY_NOTARY_TEAM_ID="TEAMID"
export PETFY_NOTARY_PASSWORD="app-specific-password"
./pet package-macos-signed
```

## What the signed build does

The signed package flow:

1. Builds the Flutter macOS release app.
2. Copies the app, runtime bridge, install helper, diagnostics helper, and uninstall helper into a package directory.
3. Signs `Petfy.app` with hardened runtime and `Runner/Release.entitlements`.
4. Verifies the code signature.
5. Creates the zip package.
6. Submits the zip to Apple notarization.
7. Staples the notarization ticket to `Petfy.app`.
8. Recreates the zip with the stapled app.

## Environment Variables

```text
PETFY_MACOS_SIGN_IDENTITY      Required for signed builds.
PETFY_NOTARY_KEYCHAIN_PROFILE  Preferred notarization credential.
PETFY_NOTARY_APPLE_ID          Alternative notarization Apple ID.
PETFY_NOTARY_TEAM_ID           Alternative notarization team ID.
PETFY_NOTARY_PASSWORD          Alternative app-specific password.
PETFY_MACOS_NOTARIZE=1         Requests notarization when calling package script directly.
```

## Notes

`Release.entitlements` disables the App Sandbox because Petfy needs user-level filesystem access for:

- `~/.codex`
- `~/.petfy`
- `~/Library/LaunchAgents`
- `~/Library/Application Support/Petfy`

That is appropriate for Developer ID distribution outside the Mac App Store.
