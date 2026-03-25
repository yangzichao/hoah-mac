#!/bin/bash
set -e

# Build Mac App Store Archive
# This script builds an archive for Mac App Store submission

VERSION=${1:-"3.6.0"}
SCHEME="HoAh"
CONFIGURATION="App Store"
ARCHIVE_PATH="./build/HoAh-MAS.xcarchive"

echo "========================================="
echo "Building Mac App Store Archive"
echo "Version: $VERSION"
echo "Configuration: $CONFIGURATION"
echo "========================================="

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$ARCHIVE_PATH"
rm -rf "./build/HoAh-MAS.pkg"

# Build archive
echo "Building archive..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$(echo $VERSION | tr -d '.')"

echo "========================================="
echo "Archive created successfully!"
echo "Location: $ARCHIVE_PATH"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Export for App Store: make export-mas"
echo "2. Or use Xcode Organizer to submit"
