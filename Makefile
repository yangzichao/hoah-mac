# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/HoAh-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework
APP_GROUP_ID := group.com.yangzichao.hoah
APP_GROUP_PREFS_DIR := $(HOME)/Library/Group Containers/$(APP_GROUP_ID)/Library/Preferences
APP_GROUP_PREFS := $(APP_GROUP_PREFS_DIR)/$(APP_GROUP_ID).plist
LEGACY_PREFS := $(HOME)/Library/Preferences/com.yangzichao.hoah.plist
SANDBOX_PREFS := $(HOME)/Library/Containers/com.yangzichao.hoah/Data/Library/Preferences/com.yangzichao.hoah.plist
INFO_PLIST := Config/Info.plist
APP_STORE_INFO_PLIST := Config/Info-AppStore.plist

.PHONY: all clean whisper setup build build-release build-debug ci-release help dev dev-debug run run-release run-debug reset-onboarding sync-prefs dmg release-dmg archive-mas export-mas check-mas bump-version tag-release
DMG_VERSION ?= 3.7.4
MAS_VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $(APP_STORE_INFO_PLIST) 2>/dev/null || echo $(DMG_VERSION))

# Default target
all: build

# Development workflow
dev: build-release run-release
dev-debug: build-debug run-debug

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

BUILD_DIR := $(PWD)/build/DerivedData

# Build process
build: build-release

build-release: setup
	xcodebuild -scheme HoAh -configuration Release \
		CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="$(DEV_TEAM)" \
		ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES ENABLE_HARDENED_RUNTIME=NO \
		$(PROVISIONING_FLAGS) \
		-derivedDataPath $(BUILD_DIR)

build-debug: setup
	xcodebuild -scheme HoAh -configuration Debug \
		CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$(DEV_TEAM)" \
		ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES ENABLE_HARDENED_RUNTIME=NO \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG" \
		$(PROVISIONING_FLAGS) \
		-derivedDataPath $(BUILD_DIR)

# CI release build (Developer ID / Hardened Runtime, no get-task-allow)
# For sandboxed apps distributed outside App Store via DMG:
# 1. Build without code signing (sandbox requires provisioning profile for xcodebuild signing)
# 2. Manually sign with Developer ID + entitlements in sign_and_notarize.sh
ci-release: setup
	xcodebuild -scheme HoAh -configuration Release \
		CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual \
		PROVISIONING_PROFILE_SPECIFIER="" PROVISIONING_PROFILE="" \
		ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES \
		-derivedDataPath $(BUILD_DIR)

# Run application
run: run-release

run-release:
	@APP_PATH="$(BUILD_DIR)/Build/Products/Release/HoAh.app"; \
	if [ -d "$$APP_PATH" ]; then \
		echo "Launching: $$APP_PATH"; \
		open "$$APP_PATH"; \
	else \
		echo "HoAh.app not found at $$APP_PATH. Run 'make build' first."; \
		exit 1; \
	fi

run-debug:
	@APP_PATH="$(BUILD_DIR)/Build/Products/Debug/HoAh.app"; \
	if [ -d "$$APP_PATH" ]; then \
		echo "Launching: $$APP_PATH"; \
		open "$$APP_PATH"; \
	else \
		echo "HoAh.app not found at $$APP_PATH. Run 'make build-debug' first."; \
		exit 1; \
	fi

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR)
	@echo "Clean complete"

sync-prefs:
	@echo "Syncing legacy preferences into App Group defaults..."
	@SRC_PREFS=""; \
	if [ -f "$(SANDBOX_PREFS)" ]; then \
		SRC_PREFS="$(SANDBOX_PREFS)"; \
	elif [ -f "$(LEGACY_PREFS)" ]; then \
		SRC_PREFS="$(LEGACY_PREFS)"; \
	else \
		echo "No legacy preferences found to sync"; \
		exit 0; \
	fi; \
	mkdir -p "$(APP_GROUP_PREFS_DIR)"; \
	cp -p "$$SRC_PREFS" "$(APP_GROUP_PREFS)"; \
	echo "Preferences copied to $(APP_GROUP_PREFS)"

# Reset onboarding flow so the app behaves like first launch
reset-onboarding:
	@echo "Resetting onboarding state for HoAh..."
	@mkdir -p "$(APP_GROUP_PREFS_DIR)"
	@python3 -c "\
import plistlib, json, os; \
plist_path = os.path.expanduser('$(APP_GROUP_PREFS)'); \
plist = plistlib.load(open(plist_path, 'rb')) if os.path.exists(plist_path) else {}; \
key = 'AppSettingsState_v1'; \
data = json.loads(plist.get(key, b'{}')) if key in plist else {}; \
data['hasCompletedOnboarding'] = False; \
plist[key] = json.dumps(data).encode(); \
plistlib.dump(plist, open(plist_path, 'wb')); \
print('Done: hasCompletedOnboarding = False')" 2>/dev/null || \
	(defaults delete $(APP_GROUP_ID) AppSettingsState_v1 2>/dev/null; echo "Fallback: deleted all settings")
	@echo "Next launch will show the onboarding flow."

# Build signed DMG with Applications link (uses Release build)
dmg:
	@bash scripts/packaging/build_dmg.sh $(DMG_VERSION)

# Build, sign, notarize, and staple DMG (requires SIGN_IDENTITY/TEAM_ID and notary credentials)
release-dmg:
	@bash scripts/packaging/sign_and_notarize.sh $(DMG_VERSION)

# Mac App Store targets
archive-mas:
	@echo "Building Mac App Store archive..."
	@bash scripts/packaging/build_mas_archive.sh $(MAS_VERSION)

export-mas:
	@echo "Exporting Mac App Store package..."
	@bash scripts/packaging/export_mas.sh

check-mas:
	@echo "Checking App Store configuration..."
	@bash scripts/packaging/check_setup.sh

# Versioning helpers
bump-version:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make bump-version VERSION=X.Y.Z [BUILD=XYZ]"; exit 1; fi
	@bash scripts/release/bump_version.sh "$(VERSION)" "$(BUILD)"

tag-release:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make tag-release VERSION=X.Y.Z [BUILD=XYZ]"; exit 1; fi
	@bash scripts/release/tag_release.sh "$(VERSION)" "$(BUILD)"

# Help
help:
	@echo "Available targets:"
	@echo ""
	@echo "Development:"
	@echo "  whisper            Clone and build whisper.cpp XCFramework"
	@echo "  setup              Copy whisper XCFramework to HoAh project"
	@echo "  build              Build the HoAh Xcode project (Release config)"
	@echo "  build-debug        Build the HoAh Xcode project (Debug config)"
	@echo "  run                Launch the built HoAh app (Release)"
	@echo "  run-debug          Launch the built HoAh app (Debug)"
	@echo "  sync-prefs         Sync legacy prefs into App Group defaults"
	@echo "  dev                Build and run the app (Release config)"
	@echo "  dev-debug          Build and run the app (Debug config)"
	@echo "  reset-onboarding   Clear onboarding flag so next launch shows first-time experience"
	@echo "  clean              Remove build artifacts"
	@echo ""
	@echo "App Store:"
	@echo "  check-mas          Check App Store configuration and certificates"
	@echo "  archive-mas        Build Mac App Store archive"
	@echo "  export-mas         Export Mac App Store package (.pkg)"
	@echo ""
	@echo "Release:"
	@echo "  bump-version       Update version numbers across project files"
	@echo "  tag-release        Bump version, commit, and tag (vX.Y.Z)"
	@echo ""
	@echo "Other:"
	@echo "  all                Run full build process (default)"
	@echo "  help               Show this help message"
	@echo ""
	@echo "For App Store submission guide, see: docs/release/APP_STORE_RELEASE.md"
DEV_TEAM ?= Y646LMR36U
PROVISIONING_FLAGS ?= -allowProvisioningUpdates -allowProvisioningDeviceRegistration
