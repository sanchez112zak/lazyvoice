#!/bin/bash

echo "=== LazyVoice Troubleshooting Script ==="
echo "This script will help diagnose why LazyVoice might not be working on your Mac."
echo ""

# Check system architecture
echo "1. Checking system architecture..."
ARCH=$(uname -m)
echo "   Your Mac architecture: $ARCH"
if [ "$ARCH" != "arm64" ]; then
    echo "   ❌ ERROR: LazyVoice requires Apple Silicon (M1/M2/M3). You have Intel: $ARCH"
    echo "   Solution: This app only works on Apple Silicon Macs (M1, M2, M3, etc.)"
    exit 1
else
    echo "   ✅ Architecture compatible (Apple Silicon)"
fi
echo ""

# Check macOS version
echo "2. Checking macOS version..."
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR_VERSION=$(echo $MACOS_VERSION | cut -d. -f1)
MINOR_VERSION=$(echo $MACOS_VERSION | cut -d. -f2)
echo "   Your macOS version: $MACOS_VERSION"
if [ "$MAJOR_VERSION" -lt 11 ]; then
    echo "   ❌ ERROR: LazyVoice requires macOS 11.0 or later. You have: $MACOS_VERSION"
    echo "   Solution: Update to macOS Big Sur (11.0) or later"
    exit 1
else
    echo "   ✅ macOS version compatible"
fi
echo ""

# Check if app exists
echo "3. Checking app installation..."
if [ ! -d "lazyvoice.app" ]; then
    echo "   ❌ ERROR: lazyvoice.app not found in current directory"
    echo "   Solution: Make sure you've unzipped the app and are running this script in the same folder"
    exit 1
else
    echo "   ✅ lazyvoice.app found"
fi
echo ""

# Check app structure
echo "4. Checking app structure..."
if [ ! -f "lazyvoice.app/Contents/MacOS/lazyvoice" ]; then
    echo "   ❌ ERROR: Main executable missing"
    exit 1
fi
if [ ! -d "lazyvoice.app/Contents/Frameworks" ]; then
    echo "   ❌ ERROR: Frameworks directory missing"
    exit 1
fi
echo "   ✅ App structure looks good"
echo ""

# Check library dependencies
echo "5. Checking library dependencies..."
MISSING_LIBS=0
for lib in libwhisper.dylib libggml.dylib libggml-base.dylib libggml-cpu.dylib libggml-metal.dylib libggml-blas.dylib; do
    if [ ! -f "lazyvoice.app/Contents/Frameworks/$lib" ]; then
        echo "   ❌ Missing: $lib"
        MISSING_LIBS=1
    else
        echo "   ✅ Found: $lib"
    fi
done

if [ $MISSING_LIBS -eq 1 ]; then
    echo "   ERROR: Some required libraries are missing"
    exit 1
fi
echo ""

# Check permissions
echo "6. Checking permissions..."
if [ ! -x "lazyvoice.app/Contents/MacOS/lazyvoice" ]; then
    echo "   ⚠️  Fixing executable permissions..."
    chmod +x "lazyvoice.app/Contents/MacOS/lazyvoice"
    echo "   ✅ Permissions fixed"
else
    echo "   ✅ Permissions look good"
fi
echo ""

# Check model files
echo "7. Checking AI model files..."
MODEL_COUNT=0
for model in ggml-tiny.bin ggml-base.bin ggml-small.bin; do
    if [ -f "lazyvoice.app/Contents/Resources/$model" ]; then
        SIZE=$(stat -f%z "lazyvoice.app/Contents/Resources/$model" 2>/dev/null || echo "0")
        echo "   ✅ Found: $model ($(($SIZE / 1024 / 1024)) MB)"
        MODEL_COUNT=$((MODEL_COUNT + 1))
    else
        echo "   ❌ Missing: $model"
    fi
done

if [ $MODEL_COUNT -eq 0 ]; then
    echo "   ERROR: No AI model files found. The app won't work without these."
    exit 1
fi
echo ""

# Test library linking
echo "8. Testing library linking..."
if command -v otool >/dev/null 2>&1; then
    BROKEN_LINKS=$(otool -L lazyvoice.app/Contents/MacOS/lazyvoice 2>/dev/null | grep -c "not found" || echo "0")
    if [ "$BROKEN_LINKS" -gt 0 ]; then
        echo "   ❌ ERROR: Some libraries are not properly linked"
        echo "   Broken links found. Contact the developer."
        exit 1
    else
        echo "   ✅ Library linking looks good"
    fi
else
    echo "   ⚠️  Cannot test library linking (otool not available)"
fi
echo ""

# Security check
echo "9. Checking security permissions..."
if spctl -a lazyvoice.app 2>&1 | grep -q "rejected"; then
    echo "   ⚠️  App is not signed and will need manual permission"
    echo "   SOLUTION:"
    echo "   1. Right-click lazyvoice.app and select 'Open'"
    echo "   2. When prompted, click 'Open' again"
    echo "   3. After that, you can launch it normally"
else
    echo "   ✅ App should launch without security warnings"
fi
echo ""

# Try to launch the app
echo "10. Attempting to launch app..."
echo "    Opening lazyvoice.app..."
open lazyvoice.app
sleep 3

# Check if app is running
if pgrep -f "lazyvoice" >/dev/null; then
    echo "   ✅ SUCCESS! LazyVoice appears to be running"
    echo ""
    echo "=== SUCCESS ==="
    echo "LazyVoice should now be running. Look for it in your menu bar."
    echo "If you don't see it, check your System Preferences > Privacy & Security > Microphone"
    echo "and make sure LazyVoice has microphone access."
else
    echo "   ❌ App failed to start"
    echo ""
    echo "=== TROUBLESHOOTING ==="
    echo "The app failed to start. Try these steps:"
    echo "1. Make sure you have at least 4GB of free RAM"
    echo "2. Check Console.app for error messages"
    echo "3. Try running: sudo xattr -cr lazyvoice.app"
    echo "4. Contact the developer with your system info:"
    echo "   - macOS version: $MACOS_VERSION"
    echo "   - Architecture: $ARCH"
    echo "   - Available RAM: $(system_profiler SPHardwareDataType | grep "Memory:" | awk '{print $2 " " $3}')"
fi

echo ""
echo "=== End of troubleshooting ===" 