#!/usr/bin/env bash
# Install Sugoso.app to ~/Applications and register a LaunchAgent so it
# starts automatically at login (and starts it right now).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Sugoso"
BUNDLE_ID="com.sugoso.app"
SRC_APP="build/${APP_NAME}.app"
DEST_DIR="${HOME}/Applications"
DEST_APP="${DEST_DIR}/${APP_NAME}.app"
LA_DIR="${HOME}/Library/LaunchAgents"
PLIST="${LA_DIR}/${BUNDLE_ID}.plist"

# 1. Build first if needed.
if [ ! -d "${SRC_APP}" ]; then
    echo "▶ No build found - building first…"
    ./build.sh
fi

# 2. Copy the app into ~/Applications.
mkdir -p "${DEST_DIR}"
rm -rf "${DEST_APP}"
cp -R "${SRC_APP}" "${DEST_APP}"
echo "✓ Installed ${DEST_APP}"

# 3. Write the LaunchAgent with the real app path baked in. Use bash string
#    replacement (not sed) so a character such as '#' in the path can't break the
#    delimiter and corrupt the generated plist / what launchd is told to run.
mkdir -p "${LA_DIR}"
APP_BIN="${DEST_APP}/Contents/MacOS/${APP_NAME}"
template="$(cat "${BUNDLE_ID}.plist")"
printf '%s\n' "${template//__APP_PATH__/${APP_BIN}}" > "${PLIST}"
echo "✓ Wrote ${PLIST}"

# 4. (Re)load it into the GUI session.
UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}/${BUNDLE_ID}" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "${PLIST}"
echo "✓ Loaded - Sugoso is running now and will start at every login."
echo
echo "To stop & remove auto-start:"
echo "  launchctl bootout gui/${UID_NUM}/${BUNDLE_ID}"
echo "  rm \"${PLIST}\""
