#!/bin/bash

# Create lazyvoice.app bundle
echo "Creating lazyvoice.app bundle..."

# Build the project first
swift build -c release

# Create app bundle structure
APP_NAME="lazyvoice"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Remove existing bundle if it exists
rm -rf "${APP_BUNDLE}"

# Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Copy Info.plist
cp Info.plist "${CONTENTS_DIR}/"

# Copy model file to Resources
cp "Sources/lazyvoice/ggml-tiny.bin" "${RESOURCES_DIR}/"

# Copy app icons
if [ -d "Resources/Assets.xcassets/AppIcon.appiconset" ]; then
    # Create App Icon
    iconutil -c icns -o "${RESOURCES_DIR}/AppIcon.icns" "Resources/Assets.xcassets/AppIcon.appiconset"
    echo "App icon created successfully!"
else
    echo "Warning: App icon assets not found"
fi

# Make executable
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "lazyvoice.app created successfully!"
echo "You can now run: open ${APP_BUNDLE}" 