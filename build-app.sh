#!/bin/bash
# Builds DiscordBar and packages it into a double-clickable .app bundle.
set -euo pipefail

APP_NAME="DiscordBar"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app"

echo "Building (release)..."
swift build -c release

echo "Packaging ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DiscordBar</string>
    <key>CFBundleDisplayName</key><string>Discord Bar</string>
    <key>CFBundleIdentifier</key><string>com.local.discordbar</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>DiscordBar</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>Discord voice chat uses your microphone.</string>
    <key>NSCameraUsageDescription</key><string>Discord video calls use your camera.</string>
</dict>
</plist>
PLIST

echo "Done: $APP_DIR"
echo "Launch it with:  open \"$APP_DIR\""
echo "Look for the paper-plane icon in your menu bar."
