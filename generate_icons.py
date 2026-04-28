#!/usr/bin/env python3
"""
Generate app icons in all required sizes from the SVG source.
Requires: pip install pillow cairosvg
"""

import os
import subprocess
from pathlib import Path

def generate_icons():
    """Generate PNG icons for all platforms."""
    
    svg_source = "assets/icon.svg"
    
    # Android icon sizes (mipmap directories)
    android_sizes = {
        "ldpi": 36,
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    
    # iOS icon sizes
    ios_sizes = [
        (20, "notification-20"),
        (40, "notification-40"),
        (60, "notification-60"),
        (29, "settings-29"),
        (58, "settings-58"),
        (87, "settings-87"),
        (40, "spotlight-40"),
        (80, "spotlight-80"),
        (120, "spotlight-120"),
        (120, "iphone-120"),
        (180, "iphone-180"),
        (167, "ipad-pro-167"),
        (152, "ipad-152"),
        (180, "watch-180"),
        (196, "watch-196"),
    ]
    
    # Web sizes
    web_sizes = {
        "favicon": 32,
        "icon-192": 192,
        "icon-512": 512,
    }
    
    print("🎨 Generating app icons from SVG...")
    
    # Generate Android icons
    print("\n📱 Android icons...")
    for name, size in android_sizes.items():
        android_dir = f"android/app/src/main/res/mipmap-{name}"
        os.makedirs(android_dir, exist_ok=True)
        output = f"{android_dir}/ic_launcher.png"
        
        # Use ImageMagick convert or cairosvg
        try:
            subprocess.run([
                "convert", svg_source, 
                "-background", "none",
                "-resize", f"{size}x{size}",
                output
            ], check=True, capture_output=True)
            print(f"  ✓ {name} ({size}x{size}) → {output}")
        except (FileNotFoundError, subprocess.CalledProcessError):
            print(f"  ✗ Failed to generate {name}. Make sure ImageMagick is installed.")
            print(f"    Install: brew install imagemagick (macOS) or apt-get install imagemagick (Linux)")
    
    # Generate iOS icons
    print("\n🍎 iOS icons...")
    ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(ios_dir, exist_ok=True)
    
    for size, name in ios_sizes:
        output = f"{ios_dir}/Icon-App-{name}.png"
        try:
            subprocess.run([
                "convert", svg_source,
                "-background", "none",
                "-resize", f"{size}x{size}",
                output
            ], check=True, capture_output=True)
            print(f"  ✓ {name} ({size}x{size})")
        except (FileNotFoundError, subprocess.CalledProcessError):
            pass
    
    # Generate web icons
    print("\n🌐 Web icons...")
    web_dir = "web"
    os.makedirs(web_dir, exist_ok=True)
    
    for name, size in web_sizes.items():
        output = f"{web_dir}/{name}.png"
        try:
            subprocess.run([
                "convert", svg_source,
                "-background", "none",
                "-resize", f"{size}x{size}",
                output
            ], check=True, capture_output=True)
            print(f"  ✓ {name} ({size}x{size}) → {output}")
        except (FileNotFoundError, subprocess.CalledProcessError):
            pass
    
    print("\n✅ Icon generation complete!")
    print("\n📋 Next steps:")
    print("  1. Review generated icons in android/, ios/, and web/ directories")
    print("  2. Update web/index.html to reference the new icons:")
    print('     <link rel="icon" type="image/png" href="favicon.ico"/>')
    print("  3. Run: flutter clean && flutter pub get && flutter run")

if __name__ == "__main__":
    generate_icons()
