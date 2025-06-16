#!/bin/bash

set -e  # Exit on any error

echo "Creating portable lazyvoice.app bundle with fixed dependencies..."

# Check for model files and download if missing
MODEL_FILES=("ggml-tiny.bin" "ggml-base.bin" "ggml-small.bin")
MODEL_URLS=(
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin"
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
)

for i in "${!MODEL_FILES[@]}"; do
    MODEL_FILE="Sources/lazyvoice/${MODEL_FILES[$i]}"
    if [ ! -f "$MODEL_FILE" ]; then
        echo "Model file ${MODEL_FILES[$i]} not found. Downloading..."
        mkdir -p Sources/lazyvoice
        curl -L -o "$MODEL_FILE" "${MODEL_URLS[$i]}"
        echo "Model file ${MODEL_FILES[$i]} downloaded successfully!"
    fi
done

# Build the project first (ARM64 only)
echo "Building project for ARM64..."
swift build -c release

# Define paths
APP_NAME="lazyvoice"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"

# Whisper.cpp paths (adjust these to your actual paths)
WHISPER_BUILD_DIR="/Users/Alessandro/Documents/Startups/whisper.cpp/build"

# Remove existing bundle if it exists
rm -rf "${APP_BUNDLE}"

# Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Copy Info.plist
cp Info.plist "${CONTENTS_DIR}/"

# Copy model files to Resources
for MODEL_FILE in "${MODEL_FILES[@]}"; do
    cp "Sources/lazyvoice/${MODEL_FILE}" "${RESOURCES_DIR}/"
done

# Copy sound files to Resources
if [ -f "Sources/lazyvoice/mic on.wav" ]; then
    cp "Sources/lazyvoice/mic on.wav" "${RESOURCES_DIR}/"
    echo "Sound file 'mic on.wav' copied to Resources"
else
    echo "Warning: Sound file 'mic on.wav' not found"
fi

# Copy whisper.cpp libraries to Frameworks directory (if they exist)
echo "Copying whisper.cpp libraries..."
if [ -d "$WHISPER_BUILD_DIR" ]; then
    # Try to copy dynamic libraries first, then static libraries as fallback
    for lib in libwhisper libggml libggml-base libggml-cpu libggml-metal; do
        if [ -f "${WHISPER_BUILD_DIR}/src/${lib}.dylib" ]; then
            cp "${WHISPER_BUILD_DIR}/src/${lib}.dylib" "${FRAMEWORKS_DIR}/"
        elif [ -f "${WHISPER_BUILD_DIR}/ggml/src/${lib}.dylib" ]; then
            cp "${WHISPER_BUILD_DIR}/ggml/src/${lib}.dylib" "${FRAMEWORKS_DIR}/"
        elif [ -f "${WHISPER_BUILD_DIR}/ggml/src/ggml-cpu/${lib}.dylib" ]; then
            cp "${WHISPER_BUILD_DIR}/ggml/src/ggml-cpu/${lib}.dylib" "${FRAMEWORKS_DIR}/"
        elif [ -f "${WHISPER_BUILD_DIR}/ggml/src/ggml-metal/${lib}.dylib" ]; then
            cp "${WHISPER_BUILD_DIR}/ggml/src/ggml-metal/${lib}.dylib" "${FRAMEWORKS_DIR}/"
        else
            echo "Warning: ${lib}.dylib not found"
        fi
    done
    
    # Update library paths in the executable to use bundled libraries - FIXED VERSION
    echo "Updating library paths (fixed version)..."
    
    # Add the proper rpath for bundled frameworks
    install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "rpath already exists"
    
    # Remove problematic absolute paths
    install_name_tool -delete_rpath "/Users/Alessandro/Documents/Startups/whisper.cpp/build/src" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "rpath not present"
    install_name_tool -delete_rpath "/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "rpath not present"
    install_name_tool -delete_rpath "/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src/ggml-metal" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "rpath not present"
    
    # Fix versioned library name issue (libwhisper.1.dylib -> libwhisper.dylib)
    install_name_tool -change "@rpath/libwhisper.1.dylib" "@executable_path/../Frameworks/libwhisper.dylib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "libwhisper.1.dylib path not found"
    
    # Update all library paths to use bundled versions
    for lib in libwhisper libggml libggml-base libggml-cpu libggml-metal; do
        # Change @rpath references to @executable_path
        install_name_tool -change "@rpath/${lib}.dylib" "@executable_path/../Frameworks/${lib}.dylib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "${lib}.dylib @rpath not updated"
        
        # Change absolute paths to @executable_path
        install_name_tool -change "/Users/Alessandro/Documents/Startups/whisper.cpp/build/src/${lib}.dylib" "@executable_path/../Frameworks/${lib}.dylib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "${lib}.dylib absolute path not updated"
        install_name_tool -change "/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src/${lib}.dylib" "@executable_path/../Frameworks/${lib}.dylib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "${lib}.dylib ggml path not updated"
        install_name_tool -change "/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src/ggml-cpu/${lib}.dylib" "@executable_path/../Frameworks/${lib}.dylib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "${lib}.dylib ggml-cpu path not updated"
        install_name_tool -change "/Users/Alessandro/Documents/Startups/whisper.cpp/build/ggml/src/ggml-metal/${lib}.dylib" "@executable_path/../Frameworks/${lib}.dylib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || echo "${lib}.dylib ggml-metal path not updated"
    done
    
    echo "Library paths updated successfully!"
    
else
    echo "Warning: Whisper.cpp build directory not found at $WHISPER_BUILD_DIR"
    echo "The app may not work on other machines without these libraries."
fi

# Copy app icons
if [ -d "Resources/Assets.xcassets/AppIcon.appiconset" ]; then
    iconutil -c icns -o "${RESOURCES_DIR}/AppIcon.icns" "Resources/Assets.xcassets/AppIcon.appiconset" 2>/dev/null || echo "Icon creation failed"
    echo "App icon created successfully!"
else
    echo "Warning: App icon assets not found"
fi

# Make executable
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Verify the dependencies are correctly set
echo ""
echo "Verifying dependencies..."
echo "Library dependencies:"
otool -L "${MACOS_DIR}/${APP_NAME}" | grep -E "(libwhisper|libggml)" | sed 's/^/  /'

echo ""
echo "RPath configuration:"
otool -l "${MACOS_DIR}/${APP_NAME}" | grep -A2 LC_RPATH | sed 's/^/  /'

echo ""
echo "Portable lazyvoice.app created successfully!"
echo "Dependencies have been fixed for distribution."
echo "Run: zip -r lazyvoice-portable-fixed.zip ${APP_BUNDLE}" 