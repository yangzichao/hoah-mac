#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version> [build]"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

VERSION="$1"
BUILD="${2:-}"

"$(dirname "$0")/bump_version.sh" "$VERSION" "$BUILD"

git add Config/Info.plist Config/Info-AppStore.plist Makefile HoAh.xcodeproj/project.pbxproj

git commit -m "Bump version to $VERSION"

git tag "v$VERSION"

echo "Created tag v$VERSION"

echo "Next: git push && git push --tags"
