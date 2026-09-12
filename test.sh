#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TEST_BUILD_DIR="$SCRIPT_DIR/.build/tests"
MODULE_CACHE="$SCRIPT_DIR/.build/ModuleCache"
DEFAULT_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_PATH="${SDKROOT:-$DEFAULT_SDK_PATH}"
ARCHITECTURE="$(uname -m)"

STABLE_SDK_PATH="$(dirname "$DEFAULT_SDK_PATH")/MacOSX15.sdk"
if [ -z "${SDKROOT:-}" ] && [ -d "$STABLE_SDK_PATH" ]; then
    SDK_PATH="$STABLE_SDK_PATH"
fi

mkdir -p "$TEST_BUILD_DIR" "$MODULE_CACHE"

swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -sdk "$SDK_PATH" \
    -target "${ARCHITECTURE}-apple-macosx14.0" \
    -swift-version 5 \
    -framework AppKit \
    -framework CoreGraphics \
    Sources/SystemIdleTimeMonitor.swift \
    Sources/PresentationGuard.swift \
    Sources/BreakScheduler.swift \
    Tests/SystemIdleTimeMonitorTests.swift \
    -o "$TEST_BUILD_DIR/SystemIdleTimeMonitorTests"

"$TEST_BUILD_DIR/SystemIdleTimeMonitorTests"
