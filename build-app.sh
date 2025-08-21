#!/bin/bash

# Build script to create G710Plus.app bundle

set -e

echo "Building G710Plus.app..."

# Change to the source directory
cd "$(dirname "$0")/g710plus/g710plus"

# Build the executable and place it in the app bundle
echo "Compiling Swift sources..."
swiftc -o "G710Plus.app/Contents/MacOS/G710Plus" Classes/*.swift -framework IOKit -framework CoreGraphics -framework Foundation

# Make the executable runnable
chmod +x "G710Plus.app/Contents/MacOS/G710Plus"

# Create a simple icon if it doesn't exist
if [ ! -f "G710Plus.app/Contents/Resources/AppIcon.icns" ]; then
    echo "Creating default app icon..."
    # Create a temporary PNG icon (simple colored square)
    sips -s format png --out /tmp/g710plus_icon.png -Z 512 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns 2>/dev/null || {
        # Fallback: create a simple colored square
        echo "Creating fallback icon..."
        mkdir -p /tmp/G710Plus.iconset
        for size in 16 32 128 256 512; do
            # Create a simple colored square as PNG
            python3 -c "
from PIL import Image, ImageDraw
import sys
size = int('$size')
img = Image.new('RGB', (size, size), color='#4A90E2')
draw = ImageDraw.Draw(img)
# Draw a simple 'G' for G710Plus
draw.text((size//4, size//4), 'G', fill='white')
img.save(f'/tmp/G710Plus.iconset/icon_{size}x{size}.png')
if size >= 32:
    img.save(f'/tmp/G710Plus.iconset/icon_{size//2}x{size//2}@2x.png')
" 2>/dev/null || {
            # Final fallback: copy system icon
            cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns /tmp/g710plus_temp.icns 2>/dev/null || touch "/tmp/G710Plus.iconset/icon_${size}x${size}.png"
        }
        done
        iconutil -c icns /tmp/G710Plus.iconset -o "G710Plus.app/Contents/Resources/AppIcon.icns" 2>/dev/null || {
            # Ultimate fallback
            touch "G710Plus.app/Contents/Resources/AppIcon.icns"
        }
        rm -rf /tmp/G710Plus.iconset
    }
fi

echo "✅ G710Plus.app built successfully!"
echo "📍 Location: $(pwd)/G710Plus.app"
echo ""
echo "To install:"
echo "  cp -r G710Plus.app /Applications/"
echo ""
echo "To test:"
echo "  open G710Plus.app"
echo "  # Check Activity Monitor for 'G710Plus' process"