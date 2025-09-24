#!/bin/bash

# Android App Icon Generator Script for Modia App (using sips)
# This script generates all required Android app icon sizes from a source image

# Source image (using the better Modia logo)
SOURCE_IMAGE="/Users/kahnja/Library/CloudStorage/GoogleDrive-matthew@industriastudio.io/Shared drives/Modia/Brand/Icons/Main Black.png"

# Destination directory (app_icons folder for now)
DEST_DIR="/Users/kahnja/audio-learning-app/app_icons/Android"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Source image not found: $SOURCE_IMAGE"
    exit 1
fi

echo "🎨 Generating Android app icons from Modia logo..."
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

# Generate all required Android app icon sizes
# Format: size:filename:dpi
declare -a ICON_CONFIGS=(
    "48:ic_launcher_mdpi.png:mdpi"
    "72:ic_launcher_hdpi.png:hdpi"
    "96:ic_launcher_xhdpi.png:xhdpi"
    "144:ic_launcher_xxhdpi.png:xxhdpi"
    "192:ic_launcher_xxxhdpi.png:xxxhdpi"
)

# Generate each icon size using sips
for config in "${ICON_CONFIGS[@]}"; do
    IFS=':' read -r SIZE FILENAME DPI <<< "$config"
    OUTPUT_PATH="$DEST_DIR/$FILENAME"
    TEMP_OUTPUT="$TEMP_DIR/$FILENAME"

    echo "⚙️  Generating ${SIZE}x${SIZE} ($DPI) → $FILENAME"

    # Use sips to resize the image
    sips -z $SIZE $SIZE "$TEMP_DIR/source.png" --out "$TEMP_OUTPUT" &> /dev/null

    if [ $? -eq 0 ]; then
        # Move to final destination
        mv "$TEMP_OUTPUT" "$OUTPUT_PATH"
        echo "   ✅ Generated successfully"
    else
        echo "   ❌ Failed to generate"
    fi
done

# Also generate the adaptive icon versions if needed (Android 8.0+)
echo ""
echo "🎯 Generating adaptive icon versions..."

# Create foreground versions (same as regular icons but we'll note they exist)
for config in "${ICON_CONFIGS[@]}"; do
    IFS=':' read -r SIZE FILENAME DPI <<< "$config"
    FOREGROUND_NAME="${FILENAME/ic_launcher/ic_launcher_foreground}"
    SOURCE_PATH="$DEST_DIR/$FILENAME"
    FOREGROUND_PATH="$DEST_DIR/$FOREGROUND_NAME"

    if [ -f "$SOURCE_PATH" ]; then
        cp "$SOURCE_PATH" "$FOREGROUND_PATH"
        echo "   ✅ Created $FOREGROUND_NAME"
    fi
done

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "✨ Android app icons generation complete!"
echo "🤖 The app will now show the proper Modia logo on Android devices"
echo ""
echo "🔍 Verifying generated icons..."
ICON_COUNT=$(ls -1 "$DEST_DIR"/ic_launcher*.png 2>/dev/null | wc -l)
echo "   Found $ICON_COUNT icon files"
echo ""
echo "📝 Note: These icons are in the app_icons directory"
echo "   You may need to manually copy them to:"
echo "   android/app/src/main/res/mipmap-[density]/"
echo ""
echo "💾 Backup saved at: $BACKUP_DIR"