"""Generate app icon PNG files for Android and iOS.

Creates a walkie-talkie style icon: dark rounded square background
with a green accent ring and microphone symbol.
"""
import os
from PIL import Image, ImageDraw

# Colors
BG_DARK = (5, 5, 5)        # #050505
BG_SURFACE = (15, 15, 15)  # #0F0F0F
ACCENT = (191, 255, 0)     # #BFFF00
ACCENT_DIM = (143, 179, 0) # #8FB300
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def draw_icon(size: int) -> Image.Image:
    """Draw the app icon at the given size."""
    # Use 4x supersampling for smooth edges
    scale = 4
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: rounded square (full bleed for adaptive icon)
    draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=s * 0.22, fill=BG_DARK)

    # Outer accent ring
    cx, cy = s // 2, s // 2
    outer_r = int(s * 0.38)
    ring_w = max(int(s * 0.025), 2)
    draw.ellipse(
        [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r],
        outline=ACCENT,
        width=ring_w,
    )

    # Inner dark circle (PTT button center)
    inner_r = int(s * 0.30)
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        fill=BG_SURFACE,
    )

    # Microphone icon (simplified: rounded rectangle body + circle top)
    mic_w = int(s * 0.10)
    mic_h = int(s * 0.16)
    mic_x = cx - mic_w // 2
    mic_y = cy - mic_h // 2 - int(s * 0.02)

    # Mic body (rounded rectangle)
    draw.rounded_rectangle(
        [mic_x, mic_y, mic_x + mic_w, mic_y + mic_h],
        radius=mic_w // 2,
        fill=ACCENT,
    )

    # Mic stand (horizontal line below)
    stand_w = int(s * 0.14)
    stand_h = max(int(s * 0.012), 2)
    stand_x = cx - stand_w // 2
    stand_y = mic_y + mic_h + int(s * 0.03)
    draw.rounded_rectangle(
        [stand_x, stand_y, stand_x + stand_w, stand_y + stand_h],
        radius=stand_h // 2,
        fill=ACCENT,
    )

    # Mic arc (curved bracket around mic)
    arc_r = int(s * 0.11)
    arc_w = max(int(s * 0.018), 2)
    draw.arc(
        [cx - arc_r, cy - arc_r - int(s * 0.02), cx + arc_r, cy + arc_r - int(s * 0.02)],
        start=20,
        end=160,
        fill=ACCENT,
        width=arc_w,
    )

    # Vertical connector from arc bottom to stand
    conn_x = cx
    conn_y1 = cy + int(s * 0.08)
    conn_y2 = stand_y
    conn_w = max(int(s * 0.012), 2)
    draw.line(
        [(conn_x, conn_y1), (conn_x, conn_y2)],
        fill=ACCENT,
        width=conn_w,
    )

    # Downscale with antialiasing
    return img.resize((size, size), Image.LANCZOS)


def draw_splash(size: int) -> Image.Image:
    """Draw a simple splash screen: dark bg with centered icon."""
    scale = 4
    s = size * scale
    img = Image.new("RGBA", (s, s), BG_DARK)
    draw = ImageDraw.Draw(img)

    # Draw a simpler centered logo for splash
    cx, cy = s // 2, s // 2
    outer_r = int(s * 0.15)

    # Accent ring
    ring_w = max(int(s * 0.008), 3)
    draw.ellipse(
        [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r],
        outline=ACCENT,
        width=ring_w,
    )

    # Inner circle
    inner_r = int(s * 0.12)
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        fill=BG_SURFACE,
    )

    # Mic symbol
    mic_w = int(s * 0.04)
    mic_h = int(s * 0.06)
    draw.rounded_rectangle(
        [cx - mic_w // 2, cy - mic_h // 2 - int(s * 0.008),
         cx + mic_w // 2, cy + mic_h // 2 - int(s * 0.008)],
        radius=mic_w // 2,
        fill=ACCENT,
    )

    # Stand
    stand_w = int(s * 0.055)
    stand_y = cy + int(s * 0.035)
    draw.rounded_rectangle(
        [cx - stand_w // 2, stand_y, cx + stand_w // 2, stand_y + max(int(s * 0.005), 2)],
        radius=max(int(s * 0.003), 1),
        fill=ACCENT,
    )

    return img.resize((size, size), Image.LANCZOS)


def main():
    # Project root is one level up from tools/
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    # Android icon sizes (in px)
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    android_dir = os.path.join(base, "android", "app", "src", "main", "res")
    for folder, size in android_sizes.items():
        out_dir = os.path.join(android_dir, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = draw_icon(size)
        icon.save(os.path.join(out_dir, "ic_launcher.png"))
        # Also save as round icon
        icon.save(os.path.join(out_dir, "ic_launcher_round.png"))

    # Android foreground (adaptive icon, 108dp = 432px at xxxhdpi)
    fg_size = 432
    fg_dir = os.path.join(android_dir, "mipmap-anydpi-v26")
    os.makedirs(fg_dir, exist_ok=True)
    # We'll use XML for adaptive icons, but also generate foreground PNG
    fg = draw_icon(fg_size)
    fg.save(os.path.join(android_dir, "mipmap-xxxhdpi", "ic_launcher_foreground.png"))

    # iOS icon sizes
    ios_dir = os.path.join(base, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(ios_dir, exist_ok=True)

    ios_sizes = [
        (20, "20x20@1x"),
        (40, "20x20@2x"),
        (60, "20x20@3x"),
        (29, "29x29@1x"),
        (58, "29x29@2x"),
        (87, "29x29@3x"),
        (40, "40x40@1x"),
        (80, "40x40@2x"),
        (120, "40x40@3x"),
        (60, "60x60@1x"),
        (120, "60x60@2x"),
        (180, "60x60@3x"),
        (1024, "1024x1024@1x"),
    ]

    for size, name in ios_sizes:
        icon = draw_icon(size)
        # iOS icons should NOT have transparency
        bg_icon = Image.new("RGBA", (size, size), BG_DARK)
        bg_icon.paste(icon, (0, 0), icon)
        bg_icon = bg_icon.convert("RGB")
        bg_icon.save(os.path.join(ios_dir, f"icon_{name}.png"))

    # Generate splash screen image (centered logo on dark bg)
    splash = draw_splash(480)
    splash_dir = os.path.join(base, "android", "app", "src", "main", "res", "drawable")
    os.makedirs(splash_dir, exist_ok=True)
    splash.save(os.path.join(splash_dir, "splash.png"))

    print("Icons generated successfully!")
    print(f"  Android icons: {len(android_sizes)} densities")
    print(f"  iOS icons: {len(ios_sizes)} sizes")
    print(f"  Splash: 480x480")


if __name__ == "__main__":
    main()
