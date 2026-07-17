#!/bin/bash
# Build Puddles and assemble a proper macOS .app bundle.
# Requires only the Command Line Tools (no Xcode / no .xcodeproj).
set -euo pipefail

APP_NAME="Puddles"
BUNDLE_ID="com.puddles.app"
CONFIG="release"

# Resolve to the directory this script lives in, so it works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Building ($CONFIG) with Swift Package Manager…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$CONTENTS/Resources"

cp "$BIN_PATH/$APP_NAME" "$MACOS/$APP_NAME"

# Copy sprite sheets and any other bundled assets into Contents/Resources.
if [ -d "$SCRIPT_DIR/Resources" ]; then
    echo "==> Copying Resources…"
    cp -R "$SCRIPT_DIR/Resources/." "$CONTENTS/Resources/"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Sasindu Janapriya. MIT Licensed.</string>
</dict>
</plist>
PLIST

# Ad-hoc code signature so macOS will launch it locally without Gatekeeper fuss.
if command -v codesign >/dev/null 2>&1; then
    echo "==> Ad-hoc signing…"
    codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || \
        echo "    (codesign skipped — app will still run locally)"
fi

echo "==> Done: $APP_DIR"
