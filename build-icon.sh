#!/bin/bash

# Build script to generate AppIcon.icns from AppIcon.png
# Run this when you update the app icon

set -e

echo "Building app icon from AppIcon.png..."

# Check if source PNG exists
if [ ! -f "AppIcon.png" ]; then
    echo "Error: AppIcon.png not found. Please ensure the source icon file exists."
    exit 1
fi

# Create iconset directory
echo "Creating iconset directory..."
rm -rf AppIcon.iconset
mkdir -p AppIcon.iconset

# Generate all required icon sizes
echo "Generating icon sizes..."
sips -z 16 16 AppIcon.png --out AppIcon.iconset/icon_16x16.png > /dev/null
sips -z 32 32 AppIcon.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null  
sips -z 32 32 AppIcon.png --out AppIcon.iconset/icon_32x32.png > /dev/null
sips -z 64 64 AppIcon.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
sips -z 128 128 AppIcon.png --out AppIcon.iconset/icon_128x128.png > /dev/null
sips -z 256 256 AppIcon.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
sips -z 256 256 AppIcon.png --out AppIcon.iconset/icon_256x256.png > /dev/null
sips -z 512 512 AppIcon.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
sips -z 512 512 AppIcon.png --out AppIcon.iconset/icon_512x512.png > /dev/null
sips -z 1024 1024 AppIcon.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null

# Create ICNS file from iconset
echo "Creating ICNS file..."
rm -f AppIcon.icns
iconutil -c icns AppIcon.iconset

# Copy to AppBundle template location
echo "Copying to AppBundle template..."
cp AppIcon.icns g710plus/g710plus/AppBundle/AppIcon.icns

echo "✅ Icon build complete!"
echo "📍 Generated: AppIcon.icns"
echo "📍 Updated: g710plus/g710plus/AppBundle/AppIcon.icns"
echo ""
echo "Next steps:"
echo "  1. Run ./build-app.sh to rebuild the app with new icon"
echo "  2. Install: cp -r g710plus/g710plus/G710Plus.app /Applications/"