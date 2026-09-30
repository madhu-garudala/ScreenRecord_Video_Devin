#!/usr/bin/env bash
# Builds build/ScreenRecord.app from the Swift package and ad-hoc signs it.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP_NAME="ScreenRecord"
APP_DIR="build/${APP_NAME}.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp App/Info.plist "$APP_DIR/Contents/Info.plist"

codesign --force --sign "${SIGN_IDENTITY:--}" "$APP_DIR"

echo "Built $APP_DIR"
