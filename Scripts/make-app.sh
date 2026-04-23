#!/usr/bin/env bash
# Build HeadControl as a .app bundle so macOS TCC attributes camera /
# accessibility permissions to the bundle id (local.headcontrol) instead of
# the parent terminal. Also bundles the menu-bar PNG and the .icns app icon.
#
# Usage:
#   ./Scripts/make-app.sh            # debug build
#   ./Scripts/make-app.sh release    # release build

set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/HeadControl.app"

cd "$ROOT"

# 1. Build
swift build -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/HeadControl"
PLIST="$ROOT/Sources/HeadControl/Info.plist"

[[ -x "$BIN"   ]] || { echo "Binary missing: $BIN"; exit 1; }
[[ -f "$PLIST" ]] || { echo "Info.plist missing: $PLIST"; exit 1; }

# 2. Generate placeholder logos if missing
if [[ ! -f "$ROOT/Resources/AppIcon.png" || ! -f "$ROOT/Resources/MenuBarIcon.png" ]]; then
    echo "Generating placeholder logos…"
    swift "$ROOT/Scripts/generate-placeholder-logos.swift"
fi

# 3. Layout .app bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN"   "$APP/Contents/MacOS/HeadControl"
cp "$PLIST" "$APP/Contents/Info.plist"

# 4. Menu bar PNG → bundle Resources (loaded at runtime via Bundle.main)
cp "$ROOT/Resources/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"

# 5. AppIcon.png → AppIcon.icns
ICONSET_DIR="$ROOT/.build/AppIcon.iconset"
SRC_ICON="$ROOT/Resources/AppIcon.png"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16     "$SRC_ICON" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
sips -z 32 32     "$SRC_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$SRC_ICON" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
sips -z 64 64     "$SRC_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$SRC_ICON" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
sips -z 256 256   "$SRC_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC_ICON" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
sips -z 512 512   "$SRC_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC_ICON" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
cp                "$SRC_ICON"        "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

# 6. Sign — prefer a stable self-signed cert ("HeadControl Dev") so that
#    macOS TCC permissions (Camera, Accessibility) survive across rebuilds.
#    Falls back to ad-hoc signing if the cert isn't installed.
CERT_NAME="HeadControl Dev"
if security find-identity -p codesigning | grep -q "\"$CERT_NAME\""; then
    SIGN_ID="$CERT_NAME"
    echo "Signing with stable identity: $SIGN_ID"
else
    SIGN_ID="-"
    cat <<EOF
Signing ad-hoc — TCC permissions will reset after every rebuild.

To make permissions persist, create a self-signed cert (one-time):
  1. Open Keychain Access
  2. Certificate Assistant → Create a Certificate…
  3. Name: '$CERT_NAME'
     Identity Type: Self Signed Root
     Certificate Type: Code Signing
EOF
fi
codesign --force --deep --sign "$SIGN_ID" "$APP" >/dev/null

echo
echo "Built $APP"
echo "Install to /Applications: ./Scripts/install.sh"
