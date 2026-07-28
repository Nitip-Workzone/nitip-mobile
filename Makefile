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
	@echo "  Production Android Builds (NORMAL - obfuscated, signed, small):"
	@echo "  make build-apk          - NORMAL: split-per-abi release 3 APKs (36MB arm64 recommended for WA)"
	@echo "  make build-apk-wa       - NORMAL: arm64 only 36MB (WA sharing)"
	@echo "  make build-apk-fat      - NORMAL: fat universal 80MB"
	@echo "  make build-aab          - NORMAL: AAB for Play Store"
	@echo "  make build-android      - Same as build-aab"
	@echo ""
	@echo "  Debug Android Builds (with visible log overlay in HP):"
	@echo "  make build-apk-debug        - DEBUG: arm64 debug 106MB with bug icon overlay to see WebView logs"
	@echo "  make build-apk-debug-fat    - DEBUG: fat debug universal"
	@echo "  make build-apk-release-noobfs - RELEASE no-obfuscate (test if 500 due to R8)"
	@echo ""
	@echo "  Flags:"
	@echo "  NORMAL = --release --obfuscate --split-debug-info --split-per-abi + minify + shrink (signed CN=Nihtip.com)"
	@echo "  DEBUG  = --debug --split-per-abi (no obfuscate, ada overlay debug log di merchant page)"

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

# Build production APK (sideload / direct install) - optimized Phase 1+2
# --obfuscate + --split-debug-info: smaller + secure
# --split-per-abi: 1 ABI per APK (arm64-v8a is 95% of devices) = ~40% smaller download
# =========================================================
# APK BUILD FLAGS - Pisah Normal vs Debug
# Normal (Release): obfuscate + split-debug-info + split-per-abi + minify + shrink (aman, kecil, signed)
# Debug: tanpa obfuscate, tanpa tree-shake-icons, ada debug log overlay di WebView, bisa lihat log di HP
# =========================================================

# Build production APK (sideload / direct install via WA) - NORMAL RELEASE (Optimized)
# Untuk share via WA, pakai arm64-v8a untuk HP baru, fat untuk universal
build-apk:
	@echo "🔨 Building Nitip APK (NORMAL RELEASE - Production Optimized)..."
	@echo "   BASE_URL : $$(jq -r '.BASE_URL' env.json)"
	@echo "   ENV      : $$(jq -r '.ENV' env.json)"
	@echo "   Version  : $$(grep '^version:' pubspec.yaml | awk '{print $$2}')"
	@echo "   Flags    : NORMAL = --release --obfuscate --split-debug-info --split-per-abi + minify + shrink"
	@echo ""
	@echo "🧹 Cleaning old builds..."
	@rm -rf build/app/outputs/flutter-apk/ 2>/dev/null || true
	@rm -rf build/app/outputs/apk/ 2>/dev/null || true
	@rm -rf build/symbols/* 2>/dev/null || true
	@mkdir -p build/symbols
	@echo "   Old APKs cleaned."
	@$(FLUTTER) build apk --release --obfuscate --split-debug-info=build/symbols --split-per-abi --dart-define-from-file=env.json
	@echo ""
	@echo "✅ APKs built successfully (per ABI) - NORMAL RELEASE - CLEAN BUILD!"
	@ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
	@echo ""
	@echo "   📱 Untuk WA (Recommended):"
	@echo "   - HP baru (2020+): app-arm64-v8a-release.apk (36MB, paling kecil & cepat) <- pakai ini untuk WA"
	@echo "   - HP lama 32-bit: app-armeabi-v7a-release.apk (32MB)"
	@echo "   - Universal (semua HP tapi besar): build-apk-fat -> app-release.apk (80MB)"
	@echo ""
	@echo "   Kirim via WA sebagai Document (bukan Gallery) agar tidak corrupt!"

build-apk-fat:
	@echo "🔨 Building Fat APK (NORMAL - all ABIs, universal - 80MB, untuk WA jika tidak tau HP user)..."
	@echo "🧹 Cleaning old fat APK..."
	@rm -rf build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || true
	@mkdir -p build/symbols
	@$(FLUTTER) build apk --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env.json
	@echo "✅ Fat APK built (NORMAL universal)!"
	@ls -lh build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || true
	@echo "   Share via WA Document (bukan Gallery) -> 80MB"

# Build production AAB (Google Play Store) - NORMAL
build-aab:
	@echo "🔨 Building Nitip App Bundle (NORMAL - Production Optimized)..."
	@echo "   BASE_URL : $$(jq -r '.BASE_URL' env.json)"
	@echo "   ENV      : $$(jq -r '.ENV' env.json)"
	@echo "   Version  : $$(grep '^version:' pubspec.yaml | awk '{print $$2}')"
	@echo ""
	@echo "🧹 Cleaning old AAB..."
	@rm -rf build/app/outputs/bundle/release/ 2>/dev/null || true
	@mkdir -p build/symbols
	@$(FLUTTER) build appbundle --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env.json
	@echo ""
	@echo "✅ App Bundle built successfully (NORMAL)!"
	@echo "📦 Output: build/app/outputs/bundle/release/app-release.aab"
	@ls -lh build/app/outputs/bundle/release/app-release.aab 2>/dev/null || true

# WA single ABI for sharing - NORMAL
build-apk-wa:
	@echo "📦 Building APK for WhatsApp sharing (NORMAL - arm64 only, smallest)..."
	@echo "🧹 Cleaning..."
	@rm -rf build/app/outputs/flutter-apk/ 2>/dev/null || true
	@mkdir -p build/symbols
	@$(FLUTTER) build apk --release --obfuscate --split-debug-info=build/symbols --target-platform android-arm64 --dart-define-from-file=env.json
	@ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
	@echo ""
	@echo "✅ NORMAL Release - Siap kirim via WA Document: app-arm64-v8a-release.apk (36MB)"

# =========================================================
# DEBUG BUILDS - Dengan log visible di HP (WebView debug overlay)
# =========================================================

# Debug APK for WA - with visible debug log overlay (no obfuscate, has bug icon debug)
build-apk-debug:
	@echo "🐛 Building APK DEBUG (with log visible di HP - untuk debug WebView 500)..."
	@echo "   BASE_URL : $$(jq -r '.BASE_URL' env.json)"
	@echo "   ENV      : $$(jq -r '.ENV' env.json)"
	@echo "   Flags    : DEBUG = --debug --split-per-abi (no obfuscate, ada overlay debug log)"
	@echo ""
	@echo "🧹 Cleaning..."
	@rm -rf build/app/outputs/flutter-apk/ 2>/dev/null || true
	@$(FLUTTER) build apk --debug --split-per-abi --target-platform android-arm64 --dart-define-from-file=env.json
	@echo ""
	@ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
	@echo ""
	@echo "✅ DEBUG APK built - Ada bug icon di AppBar merchant untuk lihat log live!"
	@echo "   Install: adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"

# Debug APK universal fat - for testing prod 500 issue without obfuscate
build-apk-debug-fat:
	@echo "🐛 Building Fat DEBUG APK (universal, no obfuscate)..."
	@rm -rf build/app/outputs/flutter-apk/ 2>/dev/null || true
	@$(FLUTTER) build apk --debug --dart-define-from-file=env.json
	@ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
	@echo "✅ Fat DEBUG APK built"

# Release but no obfuscate - untuk test apakah prod 500 karena R8/obfuscate
build-apk-release-noobfs:
	@echo "📦 Building APK RELEASE NO-OBFUSCATE (test if 500 due to R8)..."
	@echo "🧹 Cleaning..."
	@rm -rf build/app/outputs/flutter-apk/ 2>/dev/null || true
	@mkdir -p build/symbols
	@$(FLUTTER) build apk --release --no-obfuscate --target-platform android-arm64 --dart-define-from-file=env.json
	@ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
	@echo ""
	@echo "✅ RELEASE NO-OBFUSCATE built - test if obfuscate penyebab WebView 500"
	@echo "   Publisher: CN=Nihtip.com - Verif: apksigner verify --print-certs ..."

size:
	@echo "📊 Analyzing APK size breakdown..."
	@$(FLUTTER) build apk --analyze-size --release --dart-define-from-file=env.json 2>&1 | tail -n 100
