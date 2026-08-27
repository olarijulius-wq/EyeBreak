#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="EyeBreak"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_DIR="$SCRIPT_DIR/.build"
MODULE_CACHE="$BUILD_DIR/ModuleCache"
ICON_BUILD_DIR="$BUILD_DIR/AppIcon"
ICON_SOURCE="$ICON_BUILD_DIR/AppIcon-1024.png"
ICONSET_DIR="$ICON_BUILD_DIR/AppIcon.iconset"
ICON_FILE="$ICON_BUILD_DIR/AppIcon.icns"
ICON_GENERATOR="$ICON_BUILD_DIR/generate-app-icon"
DEFAULT_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_PATH="${SDKROOT:-$DEFAULT_SDK_PATH}"
ARCHITECTURE="$(uname -m)"
SOURCE_FILES=("$SCRIPT_DIR"/Sources/*.swift)

# Some Command Line Tools installs retain a stable macOS 15 SDK alongside a
# newer preview SDK. The stable SDK covers every API used here and can avoid a
# compiler/SDK build-version mismatch. Set SDKROOT to override this selection.
STABLE_SDK_PATH="$(dirname "$DEFAULT_SDK_PATH")/MacOSX15.sdk"
if [ -z "${SDKROOT:-}" ] && [ -d "$STABLE_SDK_PATH" ]; then
    SDK_PATH="$STABLE_SDK_PATH"
fi

if [ -d "$APP_BUNDLE" ]; then
    rm -rf "$APP_BUNDLE"
fi

if [ -d "$ICON_BUILD_DIR" ]; then
    rm -rf "$ICON_BUILD_DIR"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE" "$ICONSET_DIR"
cp "Info.plist" "$CONTENTS_DIR/Info.plist"

swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -sdk "$SDK_PATH" \
    -target "${ARCHITECTURE}-apple-macosx14.0" \
    -swift-version 5 \
    -O \
    -framework CoreGraphics \
    -framework ImageIO \
    -framework UniformTypeIdentifiers \
    "$SCRIPT_DIR/Scripts/generate_app_icon.swift" \
    -o "$ICON_GENERATOR"

"$ICON_GENERATOR" "$ICON_SOURCE"

make_icon_size() {
    local point_size="$1"
    local scale="$2"
    local pixel_size=$((point_size * scale))
    local scale_suffix=""

    if [ "$scale" -eq 2 ]; then
        scale_suffix="@2x"
    fi

    sips \
        --resampleHeightWidth "$pixel_size" "$pixel_size" \
        "$ICON_SOURCE" \
        --out "$ICONSET_DIR/icon_${point_size}x${point_size}${scale_suffix}.png" \
        >/dev/null
}

make_icon_size 16 1
make_icon_size 16 2
make_icon_size 32 1
make_icon_size 32 2
make_icon_size 128 1
make_icon_size 128 2
make_icon_size 256 1
make_icon_size 256 2
make_icon_size 512 1
make_icon_size 512 2

if ! iconutil --convert icns "$ICONSET_DIR" --output "$ICON_FILE" 2>/dev/null; then
    # iconutil in macOS 26 can reject a standards-complete iconset. Keep the
    # build working with the same PNG representations and the ICNS container
    # format when that system-tool regression is present.
    "$ICON_GENERATOR" --package-iconset "$ICONSET_DIR" "$ICON_FILE"
fi
cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"

swiftc \
    -module-cache-path "$MODULE_CACHE" \
    -sdk "$SDK_PATH" \
    -target "${ARCHITECTURE}-apple-macosx14.0" \
    -swift-version 5 \
    -O \
    -framework AppKit \
    -framework EventKit \
    -framework ServiceManagement \
    -framework SwiftUI \
    "${SOURCE_FILES[@]}" \
    -o "$MACOS_DIR/$APP_NAME"

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $SCRIPT_DIR/$APP_BUNDLE"
