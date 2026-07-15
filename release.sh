#!/bin/bash
# Build Puddles and package it into a drag-to-Applications DMG.
#
# Usage: ./release.sh [version]     e.g. ./release.sh 1.0
#
# Requires the free `create-dmg` tool (https://github.com/create-dmg/create-dmg).
set -euo pipefail

APP_NAME="Puddles"
VERSION="${1:-1.0}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DIST_DIR="$SCRIPT_DIR/dist"
STAGING_DIR="$DIST_DIR/staging"

# --- Check for create-dmg ---------------------------------------------------
if ! command -v create-dmg >/dev/null 2>&1; then
    cat <<'MSG'
error: `create-dmg` is not installed.

Puddles packages its DMG with the free create-dmg tool. Install it with Homebrew:

    brew install create-dmg

(Homepage: https://github.com/create-dmg/create-dmg)

Then re-run this script.
MSG
    exit 1
fi

# --- Build ------------------------------------------------------------------
echo "==> Building $APP_NAME.app..."
./build.sh

# --- Stage ------------------------------------------------------------------
echo "==> Staging for packaging..."
rm -rf "$DIST_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$SCRIPT_DIR/$APP_NAME.app" "$STAGING_DIR/"

# --- Package DMG ------------------------------------------------------------
echo "==> Creating $DMG_NAME..."
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 190 \
    "$DIST_DIR/$DMG_NAME" \
    "$STAGING_DIR"

rm -rf "$STAGING_DIR"
echo "==> Done: dist/$DMG_NAME"
