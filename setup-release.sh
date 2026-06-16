#!/bin/bash
set -euo pipefail

# Interactieve setup voor de GitHub Action release-pipeline.
# Vereist: gh CLI (`brew install gh && gh auth login`).
#
# Wat dit script doet:
#   1. Vraagt om je .p12 export van het Developer ID Application certificaat
#      (handmatig: Keychain Access → rechtsklik → Export Items… → .p12)
#   2. Vraagt het wachtwoord van die .p12
#   3. Genereert een random KEYCHAIN_PASSWORD voor de CI-keychain
#   4. Vraagt je App-Specific Password (account.apple.com)
#   5. Vraagt je Personal Access Token voor de tap-repo
#   6. Zet alles als GitHub secrets via `gh secret set`

REPO="${REPO:-vdboots/WarpConfigurator}"
TAP_REPO="${TAP_REPO:-vdboots/homebrew-tap}"
APPLE_ID_DEFAULT="vincent@boots.email"
APPLE_TEAM_ID_DEFAULT="HB65PP77HT"

echo "→ Release-secrets instellen voor $REPO"
echo "  Tap-repo: $TAP_REPO"
echo

read -r -p "Pad naar je .p12 export (bijv. ~/Downloads/DeveloperID.p12): " P12_PATH
P12_PATH="${P12_PATH/#\~/$HOME}"
if [ ! -f "$P12_PATH" ]; then
  echo "✗ Bestand niet gevonden: $P12_PATH"
  exit 1
fi

read -r -s -p ".p12 wachtwoord (input verborgen): " P12_PASS; echo
if [ -z "$P12_PASS" ]; then
  echo "✗ Wachtwoord vereist."
  exit 1
fi

KEYCHAIN_PW="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"

read -r -p "Apple ID e-mail [$APPLE_ID_DEFAULT]: " APPLE_ID
APPLE_ID="${APPLE_ID:-$APPLE_ID_DEFAULT}"

read -r -p "Apple Team ID [$APPLE_TEAM_ID_DEFAULT]: " APPLE_TEAM
APPLE_TEAM="${APPLE_TEAM:-$APPLE_TEAM_ID_DEFAULT}"

read -r -s -p "App-Specific Password (xxxx-xxxx-xxxx-xxxx, verborgen): " APPLE_APP_PW; echo

read -r -s -p "Personal Access Token voor $TAP_REPO (repo scope, verborgen — leeg = sla over): " TAP_PAT; echo

echo
echo "→ Secrets schrijven naar $REPO…"

base64 -i "$P12_PATH" | gh secret set APPLE_DEVELOPER_ID_CERT_P12 --repo "$REPO"
printf '%s' "$P12_PASS"     | gh secret set APPLE_DEVELOPER_ID_CERT_PASSWORD --repo "$REPO"
printf '%s' "$KEYCHAIN_PW"  | gh secret set KEYCHAIN_PASSWORD                --repo "$REPO"
printf '%s' "$APPLE_ID"     | gh secret set APPLE_ID                         --repo "$REPO"
printf '%s' "$APPLE_TEAM"   | gh secret set APPLE_TEAM_ID                    --repo "$REPO"
printf '%s' "$APPLE_APP_PW" | gh secret set APPLE_APP_SPECIFIC_PASSWORD      --repo "$REPO"

if [ -n "$TAP_PAT" ]; then
  printf '%s' "$TAP_PAT" | gh secret set TAP_REPO_TOKEN --repo "$REPO"
  gh variable set TAP_REPO --body "$TAP_REPO" --repo "$REPO"
  echo "✓ Tap-secrets gezet ($TAP_REPO)"
else
  echo "ℹ  TAP_REPO_TOKEN overgeslagen — release publiceert wel naar GitHub, maar update de cask niet automatisch."
fi

echo
echo "✓ Klaar. Verificatie:"
gh secret list --repo "$REPO"
echo
echo "Releasen:"
echo "  git tag v1.0.0 && git push origin v1.0.0"
