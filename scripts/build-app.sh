#!/usr/bin/env bash
# Builds build/Recordly.app from the Swift package and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP_NAME="Recordly"
APP_DIR="build/${APP_NAME}.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp App/Info.plist "$APP_DIR/Contents/Info.plist"
iconutil -c icns App/Recordly.iconset -o "$APP_DIR/Contents/Resources/AppIcon.icns"

codesign --force --sign "${SIGN_IDENTITY:--}" "$APP_DIR"

echo "Built $APP_DIR"
