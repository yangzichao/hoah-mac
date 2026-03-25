# HoAh App Store 发布流程

本文档记录了将 HoAh 发布到 Mac App Store 的完整流程。

## 前置条件

### 已配置的证书和 Profile
- **3rd Party Mac Developer Application**: `Zichao Yang (Y646LMR36U)` - 用于签名 App
- **3rd Party Mac Developer Installer**: `Zichao Yang (Y646LMR36U)` - 用于签名 .pkg
- **Provisioning Profile**: `com.yangzichao.hoah AppStore`

### 项目配置
- 已添加 `App Store` Build Configuration（在 `project.pbxproj` 中）
- App Store 配置使用 `Config/Info-AppStore.plist`（不含 Sparkle 更新配置）
- App Store 配置使用 `CODE_SIGN_STYLE = Manual` 和 `3rd Party Mac Developer Application` 证书
- App Store 配置 **未定义** `ENABLE_SPARKLE`，不会编译/链接 Sparkle（避免审核风险）

## 发布步骤

### 1. 更新版本号

编辑 `Config/Info-AppStore.plist`：
```xml
<key>CFBundleShortVersionString</key>
<string>3.6.0</string>
<key>CFBundleVersion</key>
<string>360</string>
```

### 2. 创建 Provisioning Profile（如需更新）

```bash
./scripts/packaging/setup_mas_profile.sh
```

这会使用 fastlane 自动创建/更新 Provisioning Profile。

### 3. 构建 Archive

```bash
source scripts/packaging/.env
make archive-mas MAS_VERSION=3.6.0
```

成功后会在 `./build/HoAh-MAS.xcarchive` 生成 Archive。

### 4. 上传到 App Store Connect

```bash
open -a Xcode ./build/HoAh-MAS.xcarchive
```

在 Xcode Organizer 中：
1. 点击 **Distribute App**
2. 选择 **App Store Connect**
3. 选择 **Upload**
4. 选择 **Automatically manage signing**
5. 点击 **Upload**

### 5. 在 App Store Connect 配置

访问 https://appstoreconnect.apple.com：
1. 选择 HoAh 应用
2. 添加截图、描述、关键词等
3. 选择刚上传的 Build
4. 提交审核

## 关键文件

| 文件 | 用途 |
|------|------|
| `Config/Info-AppStore.plist` | App Store 版本的 Info.plist |
| `scripts/packaging/.env` | 环境变量配置 |
| `scripts/packaging/build_mas_archive.sh` | 构建 Archive 脚本 |
| `scripts/packaging/setup_mas_profile.sh` | 创建 Provisioning Profile |
| `scripts/packaging/AppStore.xcconfig` | App Store 签名配置（备用） |

## 环境变量 (.env)

```bash
export TEAM_ID="Y646LMR36U"
export MAS_SIGN_IDENTITY="3rd Party Mac Developer Application: Zichao Yang (Y646LMR36U)"
export MAS_PROVISIONING_PROFILE="com.yangzichao.hoah AppStore"
export APPLE_ID="zichao.yang.phys@gmail.com"
```

## 常见问题

### Q: "No Team Found in Archive"
A: 确保使用 `App Store` configuration 构建，不是 `Release`。

### Q: 证书和 Profile 不匹配
A: 运行 `./scripts/packaging/setup_mas_profile.sh` 重新创建 Profile。

### Q: Swift Package 签名冲突
A: App Store configuration 使用 `CODE_SIGN_STYLE = Manual`，避免与 Swift Package 的自动签名冲突。

## 与 GitHub Release 的区别

| 配置 | GitHub Release | App Store |
|------|---------------|-----------|
| Configuration | Release | App Store |
| 证书 | Developer ID Application | 3rd Party Mac Developer Application |
| Info.plist | Config/Info.plist | Config/Info-AppStore.plist |
| 更新机制 | Sparkle | App Store 内置 |
