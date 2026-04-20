#!/bin/bash
set -e

# Configuration
APP_NAME="Aether"
BUILD_DIR="$(pwd)/build_artifact"
DMG_NAME="Aether_Installer.dmg"
VOL_NAME="Aether"
LOGO_PATH="AetherApp/Sources/AetherApp/Resources/logo.png"

echo "Starting Aether Release Build (Revamped)..."

# 0. Check Dependencies
if ! command -v create-dmg &> /dev/null; then
    echo "create-dmg not found. Installing via Homebrew..."
    brew install create-dmg
fi

# 1. Build Zig Backend (libaether)
echo "Building Zig Backend..."
cd libaether
zig build -Doptimize=ReleaseFast
cd ..

# 2. Build Swift Frontend (AetherApp)
echo "Building Swift Frontend..."
cd AetherApp
rm -rf .build
swift build -c release -Xlinker -rpath -Xlinker @executable_path/../Frameworks
cd ..

# 3. Create App Bundle Structure
echo "Creating App Bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Frameworks"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"

# 4. Copy Binaries & Resources
echo "Copying Binaries & Resources..."
cp "AetherApp/.build/release/AetherApp" "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
# Strip debug symbols to reduce binary size significantly
strip "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"

# Copy SPM Resource Bundle (Critical for shaders/images)
BUNDLE_DIR=$(find AetherApp/.build -name "AetherApp_AetherApp.bundle" | head -n 1)
if [ -d "$BUNDLE_DIR" ]; then
    echo "Copying Resource Bundle: $BUNDLE_DIR"
    cp -r "$BUNDLE_DIR" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"
else
    echo "Warning: Resource bundle not found!"
fi

# 5. Resources & Icon Generation
echo "Generating App Icon..."
if [ -f "$LOGO_PATH" ]; then
    # Copy logo as raw resource
    cp "$LOGO_PATH" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"
    
    # Generate .iconset and .icns
    ICONSET_DIR="$BUILD_DIR/Aether.iconset"
    mkdir -p "$ICONSET_DIR"
    
    sips -z 16 16     -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_16x16.png"
    sips -z 32 32     -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_16x16@2x.png"
    sips -z 32 32     -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_32x32.png"
    sips -z 64 64     -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_32x32@2x.png"
    sips -z 128 128   -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_128x128.png"
    sips -z 256 256   -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_128x128@2x.png"
    sips -z 256 256   -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_256x256.png"
    sips -z 512 512   -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_256x256@2x.png"
    sips -z 512 512   -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_512x512.png"
    sips -z 1024 1024 -s format png "$LOGO_PATH" --out "$ICONSET_DIR/icon_512x512@2x.png"
    
    iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
else
    echo "Warning: Logo not found at $LOGO_PATH!"
fi

# Create Info.plist
echo "Creating Info.plist..."
cat > "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.okernel.aether</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 6. Ad-hoc Code Signing
echo "Signing App..."
codesign --force --deep --sign - "$BUILD_DIR/$APP_NAME.app"

# 7. Create DMG (Modern)
echo "Creating DMG (create-dmg)..."
rm -f "$DMG_NAME"

create-dmg \
  --volname "$VOL_NAME" \
  --volicon "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 150 160 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 450 160 \
  "$DMG_NAME" \
  "$BUILD_DIR/$APP_NAME.app"

echo "Compressing DMG with LZMA..."
hdiutil convert "$DMG_NAME" -format ULMO -o "Aether_Installer_Compressed.dmg"
mv "Aether_Installer_Compressed.dmg" "$DMG_NAME"

echo "Build Complete!"
echo "App stored in: $BUILD_DIR/$APP_NAME.app"
echo "DMG created: $(pwd)/$DMG_NAME"
