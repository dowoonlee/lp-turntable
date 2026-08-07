#!/bin/bash
set -euo pipefail

APP_NAME="Turntable"
APP_BUNDLE="${APP_NAME}.app"
DEST="/Applications/${APP_BUNDLE}"

cd "$(dirname "$0")/.."

./Scripts/bundle.sh

echo "Installing to ${DEST}..."
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 1
rm -rf "${DEST}"
cp -R "${APP_BUNDLE}" /Applications/

# Copying invalidates the ad-hoc signature, so re-sign in place.
codesign --force --sign - "${DEST}"

# Nudge Spotlight so ⌘Space finds it without waiting for a background pass.
mdimport "${DEST}" 2>/dev/null || true

echo "Launching..."
open -a "${DEST}"
