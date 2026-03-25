#!/bin/bash
set -e

# Export Mac App Store Package
# This script exports the archive to a .pkg file for App Store submission

ARCHIVE_PATH="./build/HoAh-MAS.xcarchive"
EXPORT_PATH="./build/MAS-Export"
EXPORT_OPTIONS_TEMPLATE="./scripts/packaging/ExportOptions-MAS.plist"
EXPORT_OPTIONS_TEMP="./build/ExportOptions-MAS-temp.plist"

echo "========================================="
echo "Exporting Mac App Store Package"
echo "========================================="

# Check if archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "Error: Archive not found at $ARCHIVE_PATH"
    echo "Run 'make archive-mas' first"
    exit 1
fi

# Check environment variables
if [ -z "$TEAM_ID" ]; then
    echo "Error: TEAM_ID environment variable not set"
    echo "Please set it in scripts/packaging/.env or export it"
    exit 1
fi

if [ -z "$MAS_PROVISIONING_PROFILE" ]; then
    echo "Warning: MAS_PROVISIONING_PROFILE not set, using default"
    MAS_PROVISIONING_PROFILE="HoAh Mac App Store"
fi

# Create temporary export options with actual values
echo "Creating export options..."
mkdir -p ./build
cp "$EXPORT_OPTIONS_TEMPLATE" "$EXPORT_OPTIONS_TEMP"
sed -i '' "s/__TEAM_ID__/$TEAM_ID/g" "$EXPORT_OPTIONS_TEMP"
sed -i '' "s/__PROVISIONING_PROFILE__/$MAS_PROVISIONING_PROFILE/g" "$EXPORT_OPTIONS_TEMP"

# Clean previous export
rm -rf "$EXPORT_PATH"

# Export archive
echo "Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_TEMP"

# Clean up temp file
rm -f "$EXPORT_OPTIONS_TEMP"

echo "========================================="
echo "Export completed successfully!"
echo "Package location: $EXPORT_PATH/HoAh.pkg"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Use Xcode Organizer to upload (recommended)"
echo "2. Or use Transporter app: https://apps.apple.com/app/transporter/id1450874784"
echo "3. Or use command line:"
echo "   xcrun altool --upload-app -f $EXPORT_PATH/HoAh.pkg -t macos -u YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD"
