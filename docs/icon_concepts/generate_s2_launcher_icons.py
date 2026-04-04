from pathlib import Path
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE_SIZE = 1024
RADIUS_RATIO = 92 / 360
CHECK_POINTS = (
    (48 / 360, 178 / 360),
    (136 / 360, 266 / 360),
    (316 / 360, 94 / 360),
)
GRADIENT_STOPS = (
    (0.0, (20, 184, 166)),
    (0.45, (99, 102, 241)),
    (1.0, (168, 85, 247)),
)

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS_ICONS = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}

ANDROID_ICONS = {
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

WEB_ICONS = {
    "web/favicon.png": 32,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
}

WEB_MASKABLE_ICONS = {
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
}


def lerp(start: int, end: int, t: float) -> int:
    return round(start + (end - start) * t)


def gradient_color(position: float) -> tuple[int, int, int]:
    for index, (stop_position, stop_color) in enumerate(GRADIENT_STOPS[1:], start=1):
        prev_position, prev_color = GRADIENT_STOPS[index - 1]
        if position <= stop_position:
            span = stop_position - prev_position
            local_t = 0 if span == 0 else (position - prev_position) / span
            return tuple(
                lerp(prev_color[channel], stop_color[channel], local_t)
                for channel in range(3)
            )
    return GRADIENT_STOPS[-1][1]


def build_gradient(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    denominator = max(1, 2 * (size - 1))

    for y in range(size):
        for x in range(size):
            pixels[x, y] = (*gradient_color((x + y) / denominator), 255)

    return image


def apply_glow(image: Image.Image) -> None:
    size = image.size[0]
    center_x = round(size * 0.36)
    center_y = round(size * 0.33)
    glow_size = size * 2

    glow_alpha = ImageOps.invert(
        Image.radial_gradient("L").resize((glow_size, glow_size), Image.Resampling.BICUBIC)
    ).point(lambda value: round(value * 0.5))
    glow = Image.new("RGBA", (glow_size, glow_size), (255, 255, 255, 0))
    glow.putalpha(glow_alpha)

    crop_left = size - center_x
    crop_top = size - center_y
    image.alpha_composite(
        glow.crop((crop_left, crop_top, crop_left + size, crop_top + size))
    )


def draw_checkmark(image: Image.Image) -> None:
    size = image.size[0]
    points = [(round(size * x), round(size * y)) for x, y in CHECK_POINTS]
    width = max(1, round(size * (58 / 360)))
    check = Image.new("RGBA", image.size, (255, 255, 255, 0))
    ImageDraw.Draw(check).line(points, fill=(255, 255, 255, 46), width=width, joint="curve")
    image.alpha_composite(check)


def script_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    windir = os.environ.get("WINDIR", r"C:\Windows")
    candidates = [
        Path(windir) / "Fonts" / "BRUSHSCI.TTF",
        Path(windir) / "Fonts" / "SCRIPTBL.TTF",
        Path(windir) / "Fonts" / "segoesc.ttf",
    ]

    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)

    return ImageFont.load_default()


def draw_wordmark(image: Image.Image) -> None:
    size = image.size[0]
    target_width = size * 0.80
    font_size = round(size * 0.38)
    font = script_font(font_size)
    measure = ImageDraw.Draw(image)
    stroke_width = max(1, round(size * 0.004))

    for candidate_size in range(font_size, round(size * 0.18), -4):
        candidate_font = script_font(candidate_size)
        bbox = measure.textbbox((0, 0), "Planly", font=candidate_font)
        if bbox[2] - bbox[0] <= target_width:
            font = candidate_font
            break

    shadow_mask = Image.new("L", image.size, 0)
    shadow_draw = ImageDraw.Draw(shadow_mask)
    bbox = measure.textbbox((0, 0), "Planly", font=font)
    text_x = round((size - (bbox[2] - bbox[0])) / 2 - bbox[0])
    text_y = round((size - (bbox[3] - bbox[1])) / 2 - bbox[1] + size * 0.02)
    shadow_draw.text(
        (text_x, text_y),
        "Planly",
        font=font,
        fill=255,
        stroke_width=stroke_width,
        stroke_fill=255,
    )
    shadow_mask = shadow_mask.filter(
        ImageFilter.GaussianBlur(radius=max(1, round(size * (24 / 360))))
    )

    shadow_layer = Image.new("RGBA", image.size, (49, 46, 129, 0))
    shadow_layer.putalpha(shadow_mask.point(lambda value: round(value * 0.45)))
    image.alpha_composite(shadow_layer, dest=(0, round(size * (22 / 360))))

    text_layer = Image.new("RGBA", image.size, (255, 255, 255, 0))
    ImageDraw.Draw(text_layer).text(
        (text_x, text_y),
        "Planly",
        font=font,
        fill=(255, 255, 255, 255),
        stroke_width=stroke_width,
        stroke_fill=(255, 255, 255, 255),
    )
    image.alpha_composite(text_layer)


def center_foreground(layer: Image.Image) -> Image.Image:
    bounds = layer.getbbox()
    if bounds is None:
        return layer

    size = layer.size[0]
    dx = round(size / 2 - (bounds[0] + bounds[2]) / 2)
    dy = round(size / 2 - (bounds[1] + bounds[3]) / 2)

    centered = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    centered.paste(layer, (dx, dy), layer)
    return centered


def rounded_icon(source: Image.Image, size: int) -> Image.Image:
    icon = source.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    radius = max(1, round(size * RADIUS_RATIO))
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    rounded = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rounded.alpha_composite(icon)
    rounded.putalpha(mask)
    return rounded


def square_icon(source: Image.Image, size: int) -> Image.Image:
    return source.resize((size, size), Image.Resampling.LANCZOS).convert("RGB")


def save_png(source: Image.Image, relative_path: str, size: int, rounded: bool) -> None:
    output_path = ROOT / relative_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    icon = rounded_icon(source, size) if rounded else square_icon(source, size)
    icon.save(output_path)
    print(f"wrote {output_path.relative_to(ROOT)} ({size}x{size})")


def save_windows_icon(source: Image.Image) -> None:
    output_path = ROOT / "windows/runner/resources/app_icon.ico"
    icon = rounded_icon(source, 256)
    icon.save(
        output_path,
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print(f"wrote {output_path.relative_to(ROOT)}")


def main() -> None:
    source = build_gradient(SOURCE_SIZE)
    apply_glow(source)

    foreground = Image.new("RGBA", (SOURCE_SIZE, SOURCE_SIZE), (0, 0, 0, 0))
    draw_checkmark(foreground)
    draw_wordmark(foreground)
    source.alpha_composite(center_foreground(foreground))

    preview_path = ROOT / "docs/icon_concepts/planly-s2-app-icon-preview.png"
    rounded_icon(source, SOURCE_SIZE).save(preview_path)
    print(f"wrote {preview_path.relative_to(ROOT)} ({SOURCE_SIZE}x{SOURCE_SIZE})")

    for relative_path, size in ANDROID_ICONS.items():
        save_png(source, relative_path, size, rounded=True)

    for filename, size in IOS_ICONS.items():
        save_png(
            source,
            f"ios/Runner/Assets.xcassets/AppIcon.appiconset/{filename}",
            size,
            rounded=False,
        )

    for filename, size in MACOS_ICONS.items():
        save_png(
            source,
            f"macos/Runner/Assets.xcassets/AppIcon.appiconset/{filename}",
            size,
            rounded=True,
        )

    for relative_path, size in WEB_ICONS.items():
        save_png(source, relative_path, size, rounded=True)

    for relative_path, size in WEB_MASKABLE_ICONS.items():
        save_png(source, relative_path, size, rounded=False)

    save_windows_icon(source)


if __name__ == "__main__":
    main()
