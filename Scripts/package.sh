#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Portals"
IDENTIFIER="${IDENTIFIER:-com.example.portals}"
VERSION="${VERSION:-1.0.0}"
BUILD_DIR="$(pwd)/.build/release"
DIST_DIR="$(pwd)/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
SIGN_IDENTITY="${IDENTITY:-${SIGN_IDENTITY:-}}"

echo "==> Building release binary"
swift build -c release --product portals

echo "==> Preparing bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>portals</string>
    <key>CFBundleIdentifier</key>
    <string>__IDENTIFIER__</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Portals</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__VERSION__</string>
    <key>CFBundleVersion</key>
    <string>__VERSION__</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

gsed -i "" "s#__IDENTIFIER__#${IDENTIFIER}#g; s#__VERSION__#${VERSION}#g" "$APP_DIR/Contents/Info.plist" 2>/dev/null || \
  sed -i "" "s#__IDENTIFIER__#${IDENTIFIER}#g; s#__VERSION__#${VERSION}#g" "$APP_DIR/Contents/Info.plist"

cp "$BUILD_DIR/portals" "$APP_DIR/Contents/MacOS/"

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "==> Codesigning with identity: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --identifier "$IDENTIFIER" --sign "$SIGN_IDENTITY" "$APP_DIR"
else
  echo "==> Skipping codesign (set IDENTITY=\"Apple Development: Name (TEAMID)\" to persist Accessibility approval across builds)"
fi

echo "==> Creating DMG at $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create -volname "${APP_NAME}" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH"
echo "==> Done. Distribute: $DMG_PATH (includes ${APP_NAME}.app)"
