"""
Apply user-provided app icon and splash image.

Source images:
  - duijiang (1254x1254 square) -> app icon for Android + iOS
  - qidong (853x1844 portrait)  -> splash screen image

Usage:
  python tools/apply_user_icons.py
"""
import os
import sys
from PIL import Image

# Project root = parent of tools/
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Source images (clipboard paths)
ICON_SRC = r'C:\Users\Administrator\.workbuddy\clipboard-images\clipboard-2026-07-12T05-23-47-971Z-6fed3506.jpg'
SPLASH_SRC = r'C:\Users\Administrator\.workbuddy\clipboard-images\clipboard-2026-07-12T05-23-47-966Z-d0179046.jpg'


def generate_android_icons(icon_img: Image.Image):
    """Generate Android launcher icons at all densities."""
    base = os.path.join(PROJECT_ROOT, 'android', 'app', 'src', 'main', 'res')
    sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for folder, size in sizes.items():
        out_dir = os.path.join(base, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = icon_img.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(out_dir, 'ic_launcher.png'))
        # Round icon (same image, Android will mask)
        resized.save(os.path.join(out_dir, 'ic_launcher_round.png'))
        print(f'  Android {folder}: {size}px')

    # Adaptive icon foreground (all densities)
    fg_sizes = {
        'mipmap-mdpi': 108,
        'mipmap-hdpi': 162,
        'mipmap-xhdpi': 216,
        'mipmap-xxhdpi': 324,
        'mipmap-xxxhdpi': 432,
    }
    for folder, size in fg_sizes.items():
        out_dir = os.path.join(base, folder)
        os.makedirs(out_dir, exist_ok=True)
        # Foreground should be the icon on transparent background
        fg = icon_img.resize((size, size), Image.LANCZOS).convert('RGBA')
        fg.save(os.path.join(out_dir, 'ic_launcher_foreground.png'))
        print(f'  Android {folder} foreground: {size}px')


def generate_ios_icons(icon_img: Image.Image):
    """Generate iOS app icons at all required sizes."""
    ios_dir = os.path.join(PROJECT_ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    os.makedirs(ios_dir, exist_ok=True)

    ios_icons = [
        ('Icon-App-20x20@1x.png', 20),
        ('Icon-App-20x20@2x.png', 40),
        ('Icon-App-20x20@3x.png', 60),
        ('Icon-App-29x29@1x.png', 29),
        ('Icon-App-29x29@2x.png', 58),
        ('Icon-App-29x29@3x.png', 87),
        ('Icon-App-40x40@1x.png', 40),
        ('Icon-App-40x40@2x.png', 80),
        ('Icon-App-40x40@3x.png', 120),
        ('Icon-App-60x60@1x.png', 60),
        ('Icon-App-60x60@2x.png', 120),
        ('Icon-App-60x60@3x.png', 180),
        ('Icon-App-76x76@1x.png', 76),
        ('Icon-App-76x76@2x.png', 152),
        ('Icon-App-83.5x83.5@2x.png', 167),
        ('Icon-App-1024x1024@1x.png', 1024),
    ]

    for filename, size in ios_icons:
        resized = icon_img.resize((size, size), Image.LANCZOS)
        # iOS icons must be opaque RGB (no alpha)
        if resized.mode != 'RGB':
            bg = Image.new('RGB', (size, size), (255, 255, 255))
            bg.paste(resized, mask=resized.split()[-1] if resized.mode == 'RGBA' else None)
            resized = bg
        resized.save(os.path.join(ios_dir, filename))
        print(f'  iOS {filename}: {size}px')


def copy_splash_image(splash_img: Image.Image):
    """Copy splash image to Flutter assets."""
    assets_dir = os.path.join(PROJECT_ROOT, 'assets', 'splash')
    os.makedirs(assets_dir, exist_ok=True)
    out_path = os.path.join(assets_dir, 'splash.png')
    splash_img.save(out_path)
    print(f'  Splash saved: {out_path} ({splash_img.size})')

    # Also save to Android drawable for native splash
    drawable_dir = os.path.join(PROJECT_ROOT, 'android', 'app', 'src', 'main', 'res', 'drawable')
    os.makedirs(drawable_dir, exist_ok=True)
    # Resize for Android (keep portrait, max height 1920)
    w, h = splash_img.size
    if h > 1920:
        new_w = int(w * 1920 / h)
        splash_resized = splash_img.resize((new_w, 1920), Image.LANCZOS)
    else:
        splash_resized = splash_img
    splash_resized.save(os.path.join(drawable_dir, 'splash.png'))
    print(f'  Android splash: {splash_resized.size}')


def main():
    print('=== Applying user app icon and splash image ===\n')

    # Load source images
    print('[1/4] Loading source images...')
    icon_img = Image.open(ICON_SRC)
    print(f'  Icon source: {icon_img.size} {icon_img.mode}')

    splash_img = Image.open(SPLASH_SRC)
    print(f'  Splash source: {splash_img.size} {splash_img.mode}')

    # Convert to RGB if needed
    if icon_img.mode != 'RGB':
        icon_img = icon_img.convert('RGB')
    if splash_img.mode != 'RGB':
        splash_img = splash_img.convert('RGB')

    # Generate icons
    print('\n[2/4] Generating Android icons...')
    generate_android_icons(icon_img)

    print('\n[3/4] Generating iOS icons...')
    generate_ios_icons(icon_img)

    print('\n[4/4] Copying splash image...')
    copy_splash_image(splash_img)

    print('\n=== Done! ===')


if __name__ == '__main__':
    main()
