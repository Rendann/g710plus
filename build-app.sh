#!/bin/bash

# Build script to create G710Plus.app bundle

set -e

# Check for verbose flag
VERBOSE_BUILD=false
if [ "$1" = "--verbose" ]; then
    VERBOSE_BUILD=true
    echo "Building G710Plus.app (VERBOSE LOGGING ENABLED)..."
else
    echo "Building G710Plus.app..."
fi

# Change to the source directory
cd "$(dirname "$0")/g710plus/g710plus"

# Ensure app bundle structure exists
mkdir -p "G710Plus.app/Contents/MacOS"
mkdir -p "G710Plus.app/Contents/Resources"

# Copy Info.plist, icon, and configuration file from source templates
echo "Copying app bundle resources..."
cp "AppBundle/Info.plist" "G710Plus.app/Contents/Info.plist"
cp "AppBundle/AppIcon.icns" "G710Plus.app/Contents/Resources/AppIcon.icns"
cp "g710plus-config.json" "G710Plus.app/Contents/Resources/g710plus-config.json"

# Build the executable and place it in the app bundle
echo "Compiling Swift sources..."
if [ "$VERBOSE_BUILD" = true ]; then
    # Build with verbose logging flag
    swiftc -D VERBOSE_LOGGING -o "G710Plus.app/Contents/MacOS/G710Plus" Classes/*.swift -framework IOKit -framework CoreGraphics -framework Foundation
else
    # Build normal version
    swiftc -o "G710Plus.app/Contents/MacOS/G710Plus" Classes/*.swift -framework IOKit -framework CoreGraphics -framework Foundation
fi

# Make the executable runnable
chmod +x "G710Plus.app/Contents/MacOS/G710Plus"

# Sign the app bundle with development certificate
echo "Signing app bundle..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | cut -d '"' -f 2)
if [ -n "$SIGNING_IDENTITY" ]; then
    codesign --force --sign "$SIGNING_IDENTITY" "G710Plus.app"
    echo "Signed with: $SIGNING_IDENTITY"
else
    echo "Warning: No development certificate found - app may require permission re-authorization"
fi

if [ "$VERBOSE_BUILD" = true ]; then
    echo "✅ G710Plus.app built successfully (VERBOSE LOGGING)!"
    echo "📍 Location: $(pwd)/G710Plus.app"
    echo ""
    echo "⚠️  VERBOSE BUILD: This app will log to stdout/stderr (visible in Console.app)"
    echo ""
else
    echo "✅ G710Plus.app built successfully!"
    echo "📍 Location: $(pwd)/G710Plus.app"
    echo ""
    echo "ℹ️  Normal build: Logs to macOS system log (viewable in Console.app)"
    echo ""
fi
echo "To install:"
echo "  cp -r G710Plus.app /Applications/"
echo ""
echo "To test:"
echo "  open G710Plus.app"
echo "  # Check Activity Monitor for 'G710Plus' process"
echo ""
echo "Build modes:"
echo "  ./build-app.sh          # Normal (system log)"
echo "  ./build-app.sh --verbose # Verbose (console output)"