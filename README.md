# Cloudflare WARP Configurator

A native SwiftUI macOS app to build, install, replace and revoke Cloudflare
WARP `.mobileconfig` profiles — without ever touching Finder or `defaults
write`.

It generates the profile, opens it in System Settings → Profiles, waits for
the user to confirm, then restarts the Cloudflare WARP daemon and frontend
in one go.

![App icon](WarpConfigurator-AppIcon-bundle/tunnel_icon_1024_rounded.png)

## Why

If you support multiple Cloudflare Zero Trust teams (a customer org, a test
org, an internal org), switching WARP between them means manually writing a
new `.mobileconfig`, double-clicking it, confirming in System Settings, and
restarting WARP. This app collapses that into a few clicks while keeping
your profile data versioned in `~/.config/warpconf/profile.json`.

## Features

- **One profile, many organisations.** Add/remove team prefixes with `+`/`−`
  buttons. Stable per-device GUIDs survive edits.
- **Detects what's installed.** Reads
  `/Library/Managed Preferences/com.cloudflare.warp.plist` so the badge tells
  you whether a profile is active and how many orgs it has.
- **Auto-import.** First run pulls the currently installed configs into the
  editor; subsequent edits stay local.
- **One-click install/replace.** Revokes the existing profile (sudo via
  AppleScript), opens System Settings, polls for activation, then restarts
  the daemon and frontend.
- **Bilingual.** English by default, Dutch when macOS is set to NL. Other
  locales fall back to English.
- **Native macOS.** SwiftUI, Hardened Runtime, signed with Developer ID,
  notarised, universal binary (arm64 + x86_64).

## Install

```sh
brew tap vdboots/tap
brew install --cask warpconfigurator
```

If Homebrew refuses to load a third-party cask:

```sh
brew tap-allowlist add vdboots/tap
# or trust just this cask:
brew trust --cask vdboots/tap/warpconfigurator
```

Or grab the `.zip` from the
[latest release](https://github.com/vdboots/WarpConfigurator/releases/latest)
and drop the app into `/Applications`.

## Usage

1. Open **Cloudflare WARP Configurator**.
2. Edit the list of organisations: each row is `Name` + `Team prefix`. The
   prefix is what Cloudflare gives you (e.g. `acme-corp`).
3. Click **Install & restart WARP**. The first sudo prompt revokes the
   existing profile. System Settings opens with the new profile queued.
4. Double-click the profile in System Settings and click **Install**.
5. The app detects the change, prompts again for sudo to restart the WARP
   daemon, and relaunches the frontend.

`Replace anyway` skips the wait if you'd rather restart immediately without
the activation poll. `Remove current profile` revokes without installing
anything new.

## Build from source

Requires macOS 14+ and Xcode 15+ (or the matching Swift toolchain).

```sh
swift run                  # quick dev launch
./build-app.sh             # build, sign, package as .app
NOTARIZE=1 NOTARY_PROFILE=warpconf ./build-app.sh   # also notarise
```

`build-app.sh` env vars:

| var | default | what it does |
|---|---|---|
| `VERSION` | `1.0.0` | bundle short version string |
| `BUILD` | `1` | bundle version |
| `ARCHS` | `native` | `universal` builds arm64 + x86_64 |
| `SIGN_IDENTITY` | auto | overrides codesign identity, `-` forces ad-hoc |
| `NOTARIZE` | `0` | set `1` to notarise + staple |
| `NOTARY_PROFILE` | — | `xcrun notarytool` keychain profile |
| `APPLE_ID` / `APPLE_TEAM_ID` / `APPLE_APP_SPECIFIC_PASSWORD` | — | alternative to `NOTARY_PROFILE` |

## Releasing via GitHub Actions

The `Release` workflow triggers on `v*` tags. It imports the Developer ID
cert into an ephemeral keychain, builds a universal binary, signs,
notarises, creates a GitHub Release with the `.zip`, and updates the
[`vdboots/homebrew-tap`](https://github.com/vdboots/homebrew-tap) cask.

Required secrets: `APPLE_DEVELOPER_ID_CERT_P12` (base64),
`APPLE_DEVELOPER_ID_CERT_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_ID`,
`APPLE_TEAM_ID`, `APPLE_APP_SPECIFIC_PASSWORD`. Optional:
`TAP_REPO_TOKEN` (PAT with `contents:write` on the tap repo) and the
`TAP_REPO` variable.

`./setup-release.sh` walks you through filling them in interactively.

Cut a new release with:

```sh
git tag v1.0.1 && git push origin v1.0.1
```

## How it works under the hood

- **Profile generation:** `PropertyListSerialization` builds the same
  `com.cloudflare.warp` payload Cloudflare ships, with stable
  `PayloadUUID`s persisted in `~/.config/warpconf/profile.json`.
- **Install:** writes the `.mobileconfig` to `NSTemporaryDirectory()` and
  hands it to `NSWorkspace.open` — macOS queues it in System Settings.
- **Detection:** stats `/Library/Managed Preferences/com.cloudflare.warp.plist`
  (modification time + parsed `configs` array) to decide if a profile is
  installed and to wait for the user's confirmation.
- **Revoke:** `osascript -e 'do shell script "profiles remove -identifier
  cloudflare_warp" with administrator privileges'`.
- **Restart:** one sudo prompt that kills both `Cloudflare WARP` (frontend)
  and `warp-svc` (daemon); launchd respawns the daemon and the frontend is
  reopened with `open -a`.

## Not supported

- **Mac App Store.** App Sandbox forbids sudo, killing system daemons, and
  installing configuration profiles. Apps that do this go through MDM, not
  the App Store.
- **MDM-installed profiles.** If a profile was pushed by Jamf/Kandji/Intune,
  the local user can't revoke it — your MDM owns it.

## License

GPL-3.0. See [LICENSE](LICENSE).

> This program is free software: you can redistribute it and/or modify it
> under the terms of the GNU General Public License as published by the
> Free Software Foundation, either version 3 of the License, or (at your
> option) any later version. This program is distributed in the hope that
> it will be useful, but WITHOUT ANY WARRANTY; without even the implied
> warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
> GNU General Public License for more details.
