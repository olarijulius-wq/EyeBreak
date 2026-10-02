#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

TEST_BUILD_DIR="$SCRIPT_DIR/.build/tests"
MODULE_CACHE="$SCRIPT_DIR/.build/ModuleCache"
DEFAULT_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_PATH="${SDKROOT:-$DEFAULT_SDK_PATH}"
ARCHITECTURE="$(uname -m)"

if [ -z "${SDKROOT:-}" ]; then
    for candidate in \
        "$(dirname "$DEFAULT_SDK_PATH")/MacOSX15.sdk" \
        /Library/Developer/CommandLineTools/SDKs/MacOSX15.sdk; do
        if [ -d "$candidate" ]; then
            SDK_PATH="$candidate"
            break
        fi
    done
fi

mkdir -p "$TEST_BUILD_DIR" "$MODULE_CACHE"

# Link the actual app types without its launch entry point. These tests never
# start NSApplication or present windows, request permissions, or change the
# user's preferences. Settings use an isolated suite cleaned up after each run.
SOURCE_FILES=()
for source_file in Sources/*.swift; do
    if [ "$source_file" != Sources/main.swift ]; then
        SOURCE_FILES+=("$source_file")
    fi
done

swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -sdk "$SDK_PATH" \
    -target "${ARCHITECTURE}-apple-macosx14.0" \
    -swift-version 5 \
    -framework AppKit \
    -framework AVFoundation \
    -framework EventKit \
    -framework ServiceManagement \
    -framework SwiftUI \
    -framework Vision \
    "${SOURCE_FILES[@]}" \
    Tests/EdgeGlowPresentationTests.swift \
    -o "$TEST_BUILD_DIR/EdgeGlowPresentationTests"

"$TEST_BUILD_DIR/EdgeGlowPresentationTests"
