#!/bin/bash
set -euo pipefail

APP_NAME="Turntable"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"

echo "Building ${APP_NAME} (${CONFIG})..."
swift build -c "$CONFIG"

echo "Packaging ${APP_BUNDLE}..."
pkill -x "${APP_NAME}" 2>/dev/null || true
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
cp ".build/${CONFIG}/${APP_NAME}" "${MACOS_DIR}/"
cp "Resources/Info.plist" "${CONTENTS_DIR}/"
codesign --force --sign - "${APP_BUNDLE}"

echo "Launching..."
open "${APP_BUNDLE}"
