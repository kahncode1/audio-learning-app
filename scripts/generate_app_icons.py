#!/usr/bin/env python3
"""
Generate iOS and Android app icons from a source image
"""

from PIL import Image
import os
import sys

def generate_ios_icons(source_path, output_dir):
    """Generate all required iOS app icon sizes with proper padding"""

    # iOS icon sizes (width x height @ scale)
    ios_sizes = [
        (20, 1),   # 20x20@1x
        (20, 2),   # 20x20@2x (40x40)
        (20, 3),   # 20x20@3x (60x60)
        (29, 1),   # 29x29@1x
        (29, 2),   # 29x29@2x (58x58)
        (29, 3),   # 29x29@3x (87x87)
        (40, 1),   # 40x40@1x
        (40, 2),   # 40x40@2x (80x80)
        (40, 3),   # 40x40@3x (120x120)
        (60, 2),   # 60x60@2x (120x120)
        (60, 3),   # 60x60@3x (180x180)
        (76, 1),   # 76x76@1x
        (76, 2),   # 76x76@2x (152x152)
        (83.5, 2), # 83.5x83.5@2x (167x167)
        (1024, 1), # 1024x1024@1x (App Store)
    ]

    # Open source image
    img = Image.open(source_path)

    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    for base_size, scale in ios_sizes:
        # Calculate actual pixel size
        actual_size = int(base_size * scale)

        # Create a new square image with white background
        icon = Image.new('RGBA', (actual_size, actual_size), (255, 255, 255, 255))

        # Calculate size for the logo with padding (use 70% of icon size)
        logo_size = int(actual_size * 0.7)

        # Resize the logo while maintaining aspect ratio
        img_copy = img.copy()
        img_copy.thumbnail((logo_size, logo_size), Image.Resampling.LANCZOS)

        # Calculate position to center the logo
        x = (actual_size - img_copy.width) // 2
        y = (actual_size - img_copy.height) // 2

        # Paste the logo onto the white background
        icon.paste(img_copy, (x, y), img_copy)

        # Create filename
        if base_size == 83.5:
            filename = f"Icon-App-83.5x83.5@{scale}x.png"
        else:
            size_int = int(base_size)
            filename = f"Icon-App-{size_int}x{size_int}@{scale}x.png"

        # Save the icon
        output_path = os.path.join(output_dir, filename)
        icon.save(output_path, "PNG")
        print(f"Created: {filename} ({actual_size}x{actual_size} pixels)")

def generate_android_icons(source_path, output_dir):
    """Generate all required Android app icon sizes with proper padding"""

    # Android icon sizes for different densities
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }

    # Open source image
    img = Image.open(source_path)

    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    for folder, size in android_sizes.items():
        # Create output directory
        folder_path = os.path.join(output_dir, folder)
        os.makedirs(folder_path, exist_ok=True)

        # Create a new square image with white background
        icon = Image.new('RGBA', (size, size), (255, 255, 255, 255))

        # Calculate size for the logo with padding (use 70% of icon size)
        logo_size = int(size * 0.7)

        # Resize the logo while maintaining aspect ratio
        img_copy = img.copy()
        img_copy.thumbnail((logo_size, logo_size), Image.Resampling.LANCZOS)

        # Calculate position to center the logo
        x = (size - img_copy.width) // 2
        y = (size - img_copy.height) // 2

        # Paste the logo onto the white background
        icon.paste(img_copy, (x, y), img_copy)

        # Save as ic_launcher.png
        output_path = os.path.join(folder_path, 'ic_launcher.png')
        icon.save(output_path, "PNG")
        print(f"Created: {folder}/ic_launcher.png ({size}x{size} pixels)")

def main():
    # Source image path
    source_image = "assets/images/Institutes_quad_arrows.png"

    if not os.path.exists(source_image):
        print(f"Error: Source image not found at {source_image}")
        sys.exit(1)

    # Generate iOS icons
    print("\nGenerating iOS icons...")
    ios_output_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    generate_ios_icons(source_image, ios_output_dir)

    # Generate Android icons
    print("\nGenerating Android icons...")
    android_output_dir = "android/app/src/main/res"
    generate_android_icons(source_image, android_output_dir)

    print("\n✅ All app icons generated successfully!")
    print("\nNote: You may need to clean and rebuild your app for the changes to take effect:")
    print("  flutter clean")
    print("  flutter pub get")
    print("  flutter run")

if __name__ == "__main__":
    main()