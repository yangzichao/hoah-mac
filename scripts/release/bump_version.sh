#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [build]"
  exit 1
fi

VERSION="$1"
BUILD="${2:-}"

if [[ -z "$BUILD" ]]; then
  BUILD="$(echo "$VERSION" | tr -d '.')"
fi

if [[ ! "$BUILD" =~ ^[0-9]+$ ]]; then
  echo "Error: build number must be numeric (got '$BUILD')" >&2
  exit 1
fi

update_plist() {
  local plist="$1"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$plist"
}

update_plist "Config/Info.plist"
update_plist "Config/Info-AppStore.plist"

# Keep Makefile defaults aligned for manual builds
perl -pi -e "s/^DMG_VERSION\s*\?=\s*.*/DMG_VERSION ?= $VERSION/" Makefile
perl -pi -e "s/^MAS_VERSION\s*=\s*.*/MAS_VERSION = $VERSION/" Makefile

# Keep Xcode project marketing/build versions aligned
# Note: ${1} avoids ambiguity when VERSION/BUILD start with digits (e.g. "$13.6.0" would be parsed as capture group 13).
perl -pi -e 's/(MARKETING_VERSION = )[^;]+;/${1}'"$VERSION"';/g' HoAh.xcodeproj/project.pbxproj
perl -pi -e 's/(CURRENT_PROJECT_VERSION = )[^;]+;/${1}'"$BUILD"';/g' HoAh.xcodeproj/project.pbxproj

echo "Updated version to $VERSION ($BUILD)"
