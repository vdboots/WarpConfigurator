#!/bin/bash
set -euo pipefail

# Bouwt WarpConfigurator.app.
#
# Env-vars (allemaal optioneel):
#   VERSION                  default 1.0.0
#   BUILD                    default 1
#   ARCHS                    "native" (default) of "universal"
#   SIGN_IDENTITY            "Developer ID Application: …" — auto-detect als leeg
#                            zet op "-" om ad-hoc te forceren
#   NOTARIZE=1               notariseer + staple
#   NOTARY_PROFILE           naam van opgeslagen notarytool keychain-profile
#   APPLE_ID                 alternatief voor profile: direct credentials
#   APPLE_TEAM_ID            "
#   APPLE_APP_SPECIFIC_PASSWORD "

APP_NAME="WarpConfigurator"
DISPLAY_NAME="Cloudflare WARP Configurator"
BUNDLE_ID="nl.innovative.warpconfigurator"
VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
ARCHS="${ARCHS:-native}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT/$APP_NAME.app"
ENTITLEMENTS="$ROOT/entitlements.plist"

echo "→ Release build (archs=$ARCHS)…"
if [ "$ARCHS" = "universal" ]; then
  swift build -c release --arch arm64 --arch x86_64
else
  swift build -c release
fi

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
if [ ! -x "$BIN" ]; then
  echo "✗ Binary niet gevonden op $BIN"
  exit 1
fi

echo "→ App-bundle opnieuw opbouwen…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

RES_BUNDLE="$(swift build -c release --show-bin-path)/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RES_BUNDLE" ]; then
  cp -R "$RES_BUNDLE" "$APP_DIR/Contents/Resources/"
fi

ICON_SOURCE="$ROOT/WarpConfigurator-AppIcon-bundle/WarpConfigurator.icns"
if [ -f "$ICON_SOURCE" ]; then
  cp "$ICON_SOURCE" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
  echo "⚠  AppIcon niet gevonden op $ICON_SOURCE"
fi

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>nl</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHumanReadableCopyright</key><string>© $(date +%Y)</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# --- Signing -----------------------------------------------------------------

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
USED_FALLBACK=""

if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -E 'Developer ID Application' | head -1 | awk -F '"' '{print $2}' || true)"
  if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep -E 'Apple Development' | head -1 | awk -F '"' '{print $2}' || true)"
    if [ -n "$SIGN_IDENTITY" ]; then USED_FALLBACK="apple-development"; fi
  fi
fi

if [ -z "$SIGN_IDENTITY" ] || [ "$SIGN_IDENTITY" = "-" ]; then
  echo "→ Ad-hoc codesign"
  codesign --force --sign - "$APP_DIR"
else
  echo "→ Codesign met: $SIGN_IDENTITY"
  codesign --force \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"
  if [ "$USED_FALLBACK" = "apple-development" ]; then
    echo "  ⚠  Apple Development cert gebruikt — niet bruikbaar voor distributie."
  fi
fi

echo "→ Signature verifiëren…"
codesign --verify --deep --strict --verbose=2 "$APP_DIR" 2>&1 | sed 's/^/    /'

# --- Notarization (optioneel) ------------------------------------------------

if [ "${NOTARIZE:-0}" = "1" ]; then
  NOTARY_ARGS=()
  if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
  elif [ -n "${NOTARY_PROFILE:-}" ]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
  else
    echo "✗ Geen notary credentials. Zet NOTARY_PROFILE of APPLE_ID+APPLE_TEAM_ID+APPLE_APP_SPECIFIC_PASSWORD."
    exit 1
  fi

  ZIP="$ROOT/$APP_NAME-notarize.zip"
  echo "→ Zip → $ZIP"
  /usr/bin/ditto -c -k --keepParent "$APP_DIR" "$ZIP"
  echo "→ Submit naar Apple (kan een paar minuten duren)…"
  xcrun notarytool submit "$ZIP" "${NOTARY_ARGS[@]}" --wait
  rm -f "$ZIP"
  echo "→ Stapelen…"
  xcrun stapler staple "$APP_DIR"
  echo "→ Spctl assess…"
  spctl --assess --type execute --verbose=2 "$APP_DIR" 2>&1 | sed 's/^/    /' || true
fi

echo
echo "✓ Klaar: $APP_DIR  (v$VERSION build $BUILD)"
