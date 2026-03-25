#!/usr/bin/env bash

# Build, sign, notarize, and staple a DMG in one go.
# Requirements:
#   - Xcode command line tools
#   - Developer ID Application certificate in your keychain
#   - notarytool configured (either a profile or Apple ID + app-specific password)
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   TEAM_ID="TEAMID" \
#   NOTARY_PROFILE="your-notarytool-profile" \   # or APPLE_ID/APP_PASSWORD instead
#   ./scripts/packaging/sign_and_notarize.sh [version]
#
# If version is omitted, it reads CFBundleShortVersionString from Config/Info.plist.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Config/Info.plist")}"
DERIVED_DIR="$ROOT_DIR/build/DerivedData"
DMG_PATH="$ROOT_DIR/build/HoAh-$VERSION.dmg"

# Load local environment variables if present
if [ -f "$(dirname "$0")/.env" ]; then
  source "$(dirname "$0")/.env"
fi

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"

if [ -z "$SIGN_IDENTITY" ] || [ -z "$TEAM_ID" ]; then
  echo "✖️  SIGN_IDENTITY and TEAM_ID are required." >&2
  exit 1
fi

resolve_codesign_identity() {
  local requested_identity="$1"
  local team_id="$2"

  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$requested_identity"; then
    printf '%s\n' "$requested_identity"
    return 0
  fi

  local detected_identity=""
  if [ -n "$team_id" ]; then
    detected_identity="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application: .*('"$team_id"')\)".*/\1/p' | head -n 1)"
  fi

  if [ -z "$detected_identity" ]; then
    detected_identity="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application: .*\)".*/\1/p' | head -n 1)"
  fi

  if [ -n "$detected_identity" ]; then
    echo "⚠️  Requested SIGN_IDENTITY not found in keychain: $requested_identity"
    echo "==> Falling back to detected signing identity: $detected_identity"
    printf '%s\n' "$detected_identity"
    return 0
  fi

  echo "✖️  No usable Developer ID Application identity found in keychain." >&2
  echo "==> Available signing identities:" >&2
  security find-identity -v -p codesigning >&2 || true
  return 1
}

SIGN_IDENTITY="$(resolve_codesign_identity "$SIGN_IDENTITY" "$TEAM_ID")"

echo "==> Building app (Release, Ad-Hoc)..."
xcodebuild -scheme HoAh -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" PROVISIONING_PROFILE="" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES \
  -derivedDataPath "$DERIVED_DIR"

APP_BUNDLE="$DERIVED_DIR/Build/Products/Release/HoAh.app"
ENTITLEMENTS="$ROOT_DIR/HoAh/HoAh-DeveloperID.entitlements"

echo "==> Manually signing $APP_BUNDLE with $SIGN_IDENTITY..."
codesign --force --options runtime --deep --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

echo "==> Verifying signature..."
codesign --verify --verbose "$APP_BUNDLE"

echo "==> Packaging DMG (signed app)..."
SIGN_IDENTITY="$SIGN_IDENTITY" bash "$ROOT_DIR/scripts/packaging/build_dmg.sh" "$VERSION"

if [ ! -f "$DMG_PATH" ]; then
  echo "✖️  DMG not found at $DMG_PATH" >&2
  exit 1
fi

echo "==> Signing DMG file..."
codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"

echo "==> Submitting to Apple notarization..."
if [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$DMG_PATH" --wait --progress --keychain-profile "$NOTARY_PROFILE"
elif [ -n "$APPLE_ID" ] && [ -n "$APP_PASSWORD" ]; then
  xcrun notarytool submit "$DMG_PATH" --wait --progress \
    --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD"
else
  echo "✖️  Provide NOTARY_PROFILE or APPLE_ID/APP_PASSWORD for notarization." >&2
  exit 1
fi

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "✅ Release DMG ready: $DMG_PATH"
