# Nitip Mobile - Flutter Development Shortcuts
SHELL := /bin/bash

FLUTTER_BIN = /home/cherryapple/snap/flutter/common/flutter/bin/flutter
FLUTTER = NO_FLUTTER_UPDATE=1 FLUTTER_ALREADY_LOCKED=1 $(FLUTTER_BIN)
EMULATOR = /home/cherryapple/Android/Sdk/emulator/emulator
ADB = /home/cherryapple/Android/Sdk/platform-tools/adb
AVD_NAME = Phone_p
LOCAL_IP = $(shell hostname -I | awk '{print $$1}')


.PHONY: help emu run dev doctor analyze clean update build-apk build-aab build-android

help:
	@echo "Available commands:"
	@echo "  make emu       - Launch Android Emulator (Interactive Selector)"
	@echo "  make kill-emu  - Close all running emulators"
	@echo "  make kill-emu-force - Force kill emulators and clean lock files"
	@echo "  make devices   - List all connected devices"
	@echo "  make run       - Run the app (prompts if multi-device)"
	@echo "  make run-hp    - Run specifically on real device (4ZFBB26206206936)"
	@echo "  make run-ext   - Interactive device selector (fzf)"
	@echo "  make clean     - Clean build artifacts (no-update)"
	@echo "  make update    - Update Flutter SDK and dependencies"
	@echo "  make quiet-logs - Silence noisy EGL emulation logs (Android)"
	@echo ""
	@echo "  Production Android Builds:"
	@echo "  make build-apk      - Build production APK (release)"
	@echo "  make build-aab      - Build production AAB (Play Store)"
	@echo "  make build-android  - Same as build-aab (default production build)"

emu:
	@echo "Selecting emulator..."
	@$(EMULATOR) -list-avds > .avds.tmp
	@fzf --header="Pilih Emulator Nitip (Arrow Keys + Enter)" --height=15% --layout=reverse --border < .avds.tmp > .selected_avd || true
	@AVD=$$(cat .selected_avd 2>/dev/null); rm -f .avds.tmp .selected_avd; \
	if [ -n "$$AVD" ]; then \
		echo "Launching emulator $$AVD..."; \
		$(EMULATOR) -avd $$AVD > /dev/null 2>&1 & \
	else \
		echo "No emulator selected."; \
	fi

kill-emu:
	@echo "Closing emulators (nice way)..."
	@$(ADB) devices | grep emulator | cut -f1 | xargs -I {} $(ADB) -s {} emu kill 2>/dev/null || echo "No emulators running."

kill-emu-force:
	@echo "Force killing all emulator processes..."
	@pkill -9 "[q]emu-system" || true
	@pkill -9 "[e]mulator" || true
	@echo "Cleaning up emulator lock files..."
	@rm -rf ~/.android/avd/*.avd/*.lock 2>/dev/null || true
	@rm -rf ~/.android/avd/*.avd/*.qcow2.lock 2>/dev/null || true
	@echo "Emulators force killed and locks cleaned."

devices:
	@$(FLUTTER) devices

run:
	@echo "Running Nitip Mobile..."
	@$(FLUTTER) run --no-enable-impeller --dart-define-from-file=env.json | grep -v "app_time_stats"

run-hp:
	@echo "Running specifically on Real Device..."
	@$(FLUTTER) run --no-enable-impeller -d 4ZFBB26206206936 --dart-define-from-file=env.json --dart-define=BASE_URL=http://$(LOCAL_IP):8000/api/v1/


run-ext:
	@echo "Selecting device..."
	@$(FLUTTER) devices --machine | jq -r '.[] | "\(.name) | \(.id) | \(.emulator) | \(.targetPlatform)"' > .devices.tmp
	@fzf --header="Pilih Perangkat Nitip (Arrow Keys + Enter)" --height=15% --layout=reverse --border < .devices.tmp > .selected_device 2> /dev/tty || true
	@SELECTED=$$(cat .selected_device 2>/dev/null); \
	DEVICE_ID=$$(echo "$$SELECTED" | cut -d'|' -f2 | xargs); \
	IS_EMU=$$(echo "$$SELECTED" | cut -d'|' -f3 | xargs); \
	rm -f .devices.tmp .selected_device; \
	if [ -n "$$DEVICE_ID" ]; then \
		if [ "$$IS_EMU" = "true" ]; then \
			URL="http://10.0.2.2:8000/api/v1/"; \
			echo "📱 Running on Emulator ($$DEVICE_ID)"; \
			echo "🔗 API URL: $$URL"; \
		else \
			URL="http://$(LOCAL_IP):8000/api/v1/"; \
			echo "📲 Running on Real Device ($$DEVICE_ID)"; \
			echo "🔗 API URL: $$URL (Local IP: $(LOCAL_IP))"; \
		fi; \
		$(FLUTTER) run --no-enable-impeller -d $$DEVICE_ID --dart-define-from-file=env.json --dart-define=BASE_URL=$$URL; \
	else \
		echo "No device selected."; \
	fi


dev: emu
	@echo "Waiting for emulator to be ready..."
	@sleep 5
	@$(FLUTTER) run --no-enable-impeller --dart-define-from-file=env.json

doctor:
	@$(FLUTTER) doctor

analyze:
	@$(FLUTTER) analyze

clean:
	@echo "Cleaning project (manual + flutter clean)..."
	@rm -rf build/ .dart_tool/ .flutter-plugins .flutter-plugins-dependencies ios/Pods/ ios/.symlinks/ android/.gradle/
	@rm -f /home/cherryapple/snap/flutter/common/flutter/bin/cache/lockfile
	@$(FLUTTER) clean || echo "Flutter clean failed or timed out, but manual clean completed."

update:
	@echo "Updating Flutter SDK..."
	@rm -f /home/cherryapple/snap/flutter/common/flutter/bin/cache/lockfile
	@unset NO_FLUTTER_UPDATE && unset FLUTTER_ALREADY_LOCKED && $(FLUTTER_BIN) upgrade --force
	@echo "Getting dependencies..."
	@$(FLUTTER) pub get

quiet-logs:
	@echo "Silencing EGL_emulation logs on connected devices..."
	@$(ADB) devices | grep -v "List" | grep "device$$" | cut -f1 | xargs -I {} $(ADB) -s {} shell setprop log.tag.EGL_emulation SILENT || echo "No devices found to silence."

set-gps-lolak:
	@echo "Setting emulator GPS coordinates to Desa Lolak (0.8811, 124.014)..."
	@$(ADB) devices | grep emulator | cut -f1 | xargs -I {} $(ADB) -s {} emu geo fix 124.014 0.8811 || echo "No running emulator found."

# ─────────────────────────────────────────────
# Production Android Builds
# Uses env.json for production configuration
# ─────────────────────────────────────────────

# Default production build target (AAB for Play Store)
build-android: build-aab

# Build production APK (sideload / direct install)
build-apk:
	@echo "🔨 Building Nitip APK (Production)..."
	@echo "   BASE_URL : $$(jq -r '.BASE_URL' env.json)"
	@echo "   ENV      : $$(jq -r '.ENV' env.json)"
	@echo "   Version  : $$(grep '^version:' pubspec.yaml | awk '{print $$2}')"
	@echo ""
	@rm -rf build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
	@$(FLUTTER) build apk --release --dart-define-from-file=env.json
	@echo ""
	@echo "✅ APK built successfully!"
	@echo "📦 Output: build/app/outputs/flutter-apk/app-release.apk"
	@ls -lh build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || true

# Build production AAB (Google Play Store)
build-aab:
	@echo "🔨 Building Nitip App Bundle (Production)..."
	@echo "   BASE_URL : $$(jq -r '.BASE_URL' env.json)"
	@echo "   ENV      : $$(jq -r '.ENV' env.json)"
	@echo "   Version  : $$(grep '^version:' pubspec.yaml | awk '{print $$2}')"
	@echo ""
	@rm -rf build/app/outputs/bundle/release/*.aab 2>/dev/null || true
	@$(FLUTTER) build appbundle --release --dart-define-from-file=env.json
	@echo ""
	@echo "✅ App Bundle built successfully!"
	@echo "📦 Output: build/app/outputs/bundle/release/app-release.aab"
	@ls -lh build/app/outputs/bundle/release/app-release.aab 2>/dev/null || true
