#!/bin/bash
set -euo pipefail

APP_NAME="Turntable"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

cd "$(dirname "$0")/.."

echo "Building ${APP_NAME} (release)..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"
cp "Resources/Info.plist" "${CONTENTS_DIR}/"

echo "Signing with ad-hoc identity..."
codesign --force --sign - "${APP_BUNDLE}"

echo ""
echo "Done! Run with:"
echo "  open ${APP_BUNDLE}"
