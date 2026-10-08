#!/usr/bin/env bash
# Notarize and staple Sugoso.app so it runs on *other* Macs without Gatekeeper
# warnings. This needs an Apple Developer account ($99/yr) and a "Developer ID
# Application" certificate installed in your login keychain.
#
# One-time setup:
#   1) In Xcode/Apple Developer, create & install a "Developer ID Application"
#      certificate. Find its name with:  security find-identity -p codesigning -v
#   2) Save notarization credentials as a keychain profile (uses an app-specific
#      password from appleid.apple.com):
#        xcrun notarytool store-credentials sugoso-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" \
#          --password "xxxx-xxxx-xxxx-xxxx"
#
# Each release:
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
#   ./notarize.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Sugoso"
APP_DIR="build/${APP_NAME}.app"
ZIP="build/${APP_NAME}.zip"
PROFILE="${NOTARY_PROFILE:-sugoso-notary}"

[ -d "${APP_DIR}" ] || { echo "No build found. Run: CODESIGN_IDENTITY=… ./build.sh"; exit 1; }

# Refuse to notarize an ad-hoc-signed app (it would be rejected).
if codesign -dvv "${APP_DIR}" 2>&1 | grep -q "Signature=adhoc"; then
    echo "✗ ${APP_DIR} is ad-hoc signed. Rebuild with a Developer ID:"
    echo '    CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh'
    exit 1
fi

echo "▶ Zipping for submission…"
/usr/bin/ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"

echo "▶ Submitting to Apple's notary service (this waits for the result)…"
xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait

echo "▶ Stapling the ticket to the app…"
xcrun stapler staple "${APP_DIR}"

echo "✓ Notarized & stapled: ${APP_DIR}"
echo "  Verify with: spctl -a -vvv \"${APP_DIR}\""
