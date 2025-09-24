#!/bin/bash

# iOS App Icon Generator Script for Modia App (using sips)
# This script generates all required iOS app icon sizes from a source image

# Source image (using the better Modia logo)
SOURCE_IMAGE="/Users/kahnja/Library/CloudStorage/GoogleDrive-matthew@industriastudio.io/Shared drives/Modia/Brand/Icons/Main Black.png"

# Destination directory
DEST_DIR="/Users/kahnja/audio-learning-app/ios/Runner/Assets.xcassets/AppIcon.appiconset"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image not found: $SOURCE_IMAGE"
    echo "Trying alternative location..."
    SOURCE_IMAGE="/Users/kahnja/Library/CloudStorage/GoogleDrive-matthew@industriastudio.io/Shared drives/Modia/Brand/Icons/Black Logo (large).png"
    if [ ! -f "$SOURCE_IMAGE" ]; then
        echo "❌ Alternative source image not found either"
        exit 1
    fi
fi

echo "🎨 Generating iOS app icons from Modia logo..."
echo "📁 Source: $SOURCE_IMAGE"
echo "📁 Destination: $DEST_DIR"

# Create backup of existing icons
BACKUP_DIR="${DEST_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
echo "📦 Creating backup at: $BACKUP_DIR"
cp -r "$DEST_DIR" "$BACKUP_DIR"

# Create a temporary working directory
TEMP_DIR=$(mktemp -d)
echo "🔧 Working directory: $TEMP_DIR"

# Copy source image to temp directory
cp "$SOURCE_IMAGE" "$TEMP_DIR/source.png"

# Generate all required iOS app icon sizes
# Format: size:filename
declare -a ICON_CONFIGS=(
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

# Generate each icon size using sips
for config in "${ICON_CONFIGS[@]}"; do
    SIZE="${config%%:*}"
    FILENAME="${config##*:}"
    OUTPUT_PATH="$DEST_DIR/$FILENAME"
    TEMP_OUTPUT="$TEMP_DIR/$FILENAME"

    echo "⚙️  Generating ${SIZE}x${SIZE} → $FILENAME"

    # Use sips to resize the image
    # -z height width: resizes to specific dimensions
    # -s format png: ensures PNG format
    sips -z $SIZE $SIZE "$TEMP_DIR/source.png" --out "$TEMP_OUTPUT" &> /dev/null

    if [ $? -eq 0 ]; then
        # Move to final destination
        mv "$TEMP_OUTPUT" "$OUTPUT_PATH"
        echo "   ✅ Generated successfully"
    else
        echo "   ❌ Failed to generate"
    fi
done

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "✨ iOS app icons generation complete!"
echo "📱 The app will now show the proper Modia logo on the home screen"
echo ""
echo "🔍 Verifying generated icons..."
ICON_COUNT=$(ls -1 "$DEST_DIR"/Icon-App-*.png 2>/dev/null | wc -l)
echo "   Found $ICON_COUNT icon files"
echo ""
echo "Next steps:"
echo "1. Clean the build: flutter clean"
echo "2. Rebuild the iOS app: flutter build ios"
echo "3. Run on device/simulator to see the new icon"
echo ""
echo "💾 Backup saved at: $BACKUP_DIR"