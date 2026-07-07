#!/bin/bash
# Build BarricadeAdvisor.app — a self-contained macOS app bundle with icon.
# Usage: ./build_app.sh   (output: ./BarricadeAdvisor.app)
set -euo pipefail
cd "$(dirname "$0")"

APP="Barricade Advisor"
BUNDLE="$APP.app"
ID="com.kaloyan.barricadeadvisor"

echo "==> swift build -c release"
swift build -c release
BIN=".build/release/BarricadeAdvisor"

echo "==> rendering icon"
BUILD=".build/icon"
mkdir -p "$BUILD"
swift Tools/make_icon.swift "$BUILD/icon_1024.png" >/dev/null

ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for sz in 16 32 64 128 256 512; do
  sips -z $sz $sz "$BUILD/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
  d=$((sz*2))
  sips -z $d $d "$BUILD/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
cp "$BUILD/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$BUILD/AppIcon.icns"

echo "==> assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/BarricadeAdvisor"
cp "$BUILD/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleDisplayName</key><string>$APP</string>
  <key>CFBundleExecutable</key><string>BarricadeAdvisor</string>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.board-games</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

# Ad-hoc sign so Gatekeeper lets it launch locally.
codesign --force --deep --sign - "$BUNDLE" 2>/dev/null || true
# Refresh icon cache
touch "$BUNDLE"

echo "==> done: $BUNDLE"
