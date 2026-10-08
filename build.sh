#!/usr/bin/env bash
# Compile the Swift package and wrap the binary in a proper Sugoso.app bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Sugoso"
APP_DIR="build/${APP_NAME}.app"

echo "▶ Building (release)…"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"

echo "▶ Assembling ${APP_NAME}.app…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist"    "${APP_DIR}/Contents/Info.plist"

# Sign with a real Developer ID when CODESIGN_IDENTITY is set (required to
# notarize / run on other Macs); otherwise ad-hoc sign for local use.
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "${SIGN_IDENTITY}" = "-" ]; then
    echo "▶ Code signing (ad-hoc, this Mac only)…"
    codesign --force --sign - "${APP_DIR}"
else
    echo "▶ Code signing with Developer ID: ${SIGN_IDENTITY}…"
    codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_DIR}"
fi

echo "✓ Built ${APP_DIR}"
echo "  Try it now:   open \"${APP_DIR}\""
echo "  Auto-start:   ./install.sh"
