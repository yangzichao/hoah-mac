#!/bin/bash
set -e

# 自动创建 Mac App Store Provisioning Profile
# 使用 App Store Connect API

BUNDLE_ID="com.yangzichao.hoah"
TEAM_ID="Y646LMR36U"
APPLE_ID="zichao.yang.phys@gmail.com"

echo "========================================="
echo "创建 Mac App Store Provisioning Profile"
echo "========================================="
echo ""
echo "Bundle ID: $BUNDLE_ID"
echo "Team ID: $TEAM_ID"
echo "Apple ID: $APPLE_ID"
echo ""

# 使用 fastlane sigh 创建 Profile
echo "正在创建 Provisioning Profile..."
fastlane sigh \
    --app_identifier "$BUNDLE_ID" \
    --username "$APPLE_ID" \
    --team_id "$TEAM_ID" \
    --platform macos \
    --force

echo ""
echo "========================================="
echo "完成！"
echo "========================================="
