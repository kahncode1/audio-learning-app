#!/bin/bash

# iOS App Icon Generator Script for Modia App
# This script generates all required iOS app icon sizes from a source image

# Source image (using the better Modia logo)
SOURCE_IMAGE="/Users/kahnja/Library/CloudStorage/GoogleDrive-matthew@industriastudio.io/Shared drives/Modia/Brand/Icons/Main Black.png"

# Destination directory
DEST_DIR="/Users/kahnja/audio-learning-app/ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image not found: $SOURCE_IMAGE"
    exit 1
fi

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick is not installed. Please install it first:"
    echo "brew install imagemagick"
    exit 1
fi

echo "🎨 Generating iOS app icons from Modia logo..."
echo "📁 Source: $SOURCE_IMAGE"
echo "📁 Destination: $DEST_DIR"

# Create backup of existing icons
BACKUP_DIR="${DEST_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
echo "📦 Creating backup at: $BACKUP_DIR"
cp -r "$DEST_DIR" "$BACKUP_DIR"

# Generate all required iOS app icon sizes
# Format: size:filename
ICON_SIZES=(
    "20:Icon-App-20x20@1x.png"
    "40:Icon-App-20x20@2x.png"
    "60:Icon-App-20x20@3x.png"
    "29:Icon-App-29x29@1x.png"
    "58:Icon-App-29x29@2x.png"
    "87:Icon-App-29x29@3x.png"
    "40:Icon-App-40x40@1x.png"
    "80:Icon-App-40x40@2x.png"
    "120:Icon-App-40x40@3x.png"
    "120:Icon-App-60x60@2x.png"
    "180:Icon-App-60x60@3x.png"
    "76:Icon-App-76x76@1x.png"
    "152:Icon-App-76x76@2x.png"
    "167:Icon-App-83.5x83.5@2x.png"
    "1024:Icon-App-1024x1024@1x.png"
)

# Generate each icon size
for item in "${ICON_SIZES[@]}"; do
    SIZE="${item%%:*}"
    FILENAME="${item##*:}"
    OUTPUT_PATH="$DEST_DIR/$FILENAME"

    echo "⚙️  Generating ${SIZE}x${SIZE} → $FILENAME"

    # Use ImageMagick to resize the image
    # -resize: resizes to exact dimensions
    # -gravity center: centers the image
    # -extent: ensures exact canvas size
    # -background transparent: maintains transparency if present
    convert "$SOURCE_IMAGE" \
        -resize ${SIZE}x${SIZE} \
        -gravity center \
        -extent ${SIZE}x${SIZE} \
        -background transparent \
        "$OUTPUT_PATH"

    if [ $? -eq 0 ]; then
        echo "   ✅ Generated successfully"
    else
        echo "   ❌ Failed to generate"
    fi
done

echo ""
echo "✨ iOS app icons generation complete!"
echo "📱 The app will now show the proper Modia logo on the home screen"
echo ""
echo "Next steps:"
echo "1. Clean the build: flutter clean"
echo "2. Rebuild the iOS app: flutter build ios"
echo "3. Run on device/simulator to see the new icon"
echo ""
echo "💾 Backup saved at: $BACKUP_DIR"