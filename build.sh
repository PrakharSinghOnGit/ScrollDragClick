#!/bin/bash
set -e

echo "🔨 Building ScrollClick release executable..."
swift build -c release

APP_NAME="ScrollClick.app"
BIN_PATH=".build/release/ScrollClick"

echo "📦 Packaging $APP_NAME bundle..."
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

cp "$BIN_PATH" "$APP_NAME/Contents/MacOS/ScrollClick"
cp "Info.plist" "$APP_NAME/Contents/Info.plist"

chmod +x "$APP_NAME/Contents/MacOS/ScrollClick"

echo "✅ $APP_NAME successfully created!"
echo "🚀 You can launch it using: open $APP_NAME"
