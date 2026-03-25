#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="HoAh.xcodeproj"
SCHEME="HoAh"
CONFIGURATION="App Store"
INFO_PLIST="Config/Info-AppStore.plist"

fail() {
  echo "[check-mas] ERROR: $1" >&2
  exit 1
}

warn() {
  echo "[check-mas] WARNING: $1" >&2
}

echo "[check-mas] Checking App Store configuration..."

# 1) Ensure App Store build does not enable Sparkle
BUILD_SETTINGS=$(xcodebuild -showBuildSettings -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration "$CONFIGURATION")
SWIFT_CONDITIONS=$(echo "$BUILD_SETTINGS" | awk -F ' = ' '/SWIFT_ACTIVE_COMPILATION_CONDITIONS/ {print $2; exit}')
if [[ "$SWIFT_CONDITIONS" == *"ENABLE_SPARKLE"* ]]; then
  fail "App Store configuration enables Sparkle (SWIFT_ACTIVE_COMPILATION_CONDITIONS contains ENABLE_SPARKLE)."
fi

echo "[check-mas] OK: Sparkle flag not present in App Store build settings."

# 2) Ensure App Store Info.plist doesn't include Sparkle feed/config
if /usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$INFO_PLIST" >/dev/null 2>&1; then
  fail "$INFO_PLIST contains SUFeedURL. Sparkle should be removed for App Store builds."
fi

echo "[check-mas] OK: Sparkle keys not found in $INFO_PLIST."

# 3) Sanity-check Info.plist path in project file
PBXPROJ="$PROJECT_PATH/project.pbxproj"
if rg -q "INFOPLIST_FILE = \\\"$INFO_PLIST\\\";" "$PBXPROJ"; then
  echo "[check-mas] OK: App Store Info.plist path found in project."
else
  fail "App Store Info.plist path not found in project: expected INFOPLIST_FILE = \"$INFO_PLIST\"."
fi

echo "[check-mas] Done."
