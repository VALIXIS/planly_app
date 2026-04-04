from pathlib import Path
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_PATH = ROOT / "docs" / "store_assets" / "planly-feature-graphic-1024x512.png"
ICON_PATH = ROOT / "docs" / "store_assets" / "planly-play-store-icon-512.png"
SIZE = (1024, 512)

TEAL = (20, 184, 166)
INDIGO = (99, 102, 241)
PURPLE = (168, 85, 247)
WHITE = (255, 255, 255)


def load_font(size: int, *, bold: bool = False, script: bool = False):
    windir = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
    if script:
        candidates = [windir / "BRUSHSCI.TTF", windir / "SCRIPTBL.TTF"]
    elif bold:
        candidates = [windir / "segoeuib.ttf", windir / "arialbd.ttf"]
    else:
        candidates = [windir / "segoeui.ttf", windir / "arial.ttf"]

    for font_path in candidates:
        if font_path.exists():
            return ImageFont.truetype(str(font_path), size=size)
    return ImageFont.load_default()


def mix(c1, c2, t: float):
    return tuple(round(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def build_background() -> Image.Image:
    image = Image.new("RGBA", SIZE, WHITE)
    draw = ImageDraw.Draw(image)
    width, height = SIZE

    for y in range(height):
        y_t = y / (height - 1)
        left = mix(TEAL, INDIGO, y_t * 0.55)
        right = mix(INDIGO, PURPLE, 0.35 + y_t * 0.65)
        for x in range(width):
            draw.point((x, y), fill=mix(left, right, x / (width - 1)))

    for box, alpha in [
        ((-80, -120, 360, 320), 60),
        ((620, -90, 1080, 360), 42),
        ((300, 180, 780, 680), 34),
    ]:
        glow = Image.new("RGBA", SIZE, (255, 255, 255, 0))
        ImageDraw.Draw(glow).ellipse(box, fill=(255, 255, 255, alpha))
        image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(36)))

    return image


def add_icon(image: Image.Image) -> None:
    icon = Image.open(ICON_PATH).convert("RGBA").resize((220, 220), Image.Resampling.LANCZOS)
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_alpha = icon.getchannel("A").point(lambda value: round(value * 0.35))
    shadow_layer = Image.new("RGBA", icon.size, (49, 46, 129, 0))
    shadow_layer.putalpha(shadow_alpha)
    shadow.paste(shadow_layer, (66, 166), shadow_layer)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    image.alpha_composite(shadow)
    image.alpha_composite(icon, dest=(60, 150))


def draw_text(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    script_font = load_font(98, script=True)
    title_font = load_font(28, bold=True)
    body_font = load_font(24)
    chip_font = load_font(20, bold=True)

    draw.text(
        (330, 132),
        "Planly",
        font=script_font,
        fill=WHITE,
        stroke_width=2,
        stroke_fill=WHITE,
    )
    draw.text((336, 258), "Tasks, Reminders, Calendar & Focus", font=title_font, fill=WHITE)
    draw.text((338, 320), "Plan your day, stay on track, and review your progress.", font=body_font, fill=(245, 246, 255))

    chip_labels = ["Smart Groups", "Daily Reflection", "Dark Mode"]
    chip_x = 336
    for label in chip_labels:
        bbox = draw.textbbox((0, 0), label, font=chip_font)
        chip_w = bbox[2] - bbox[0] + 40
        draw.rounded_rectangle(
            (chip_x, 388, chip_x + chip_w, 436),
            radius=24,
            fill=(36, 38, 58, 68),
            outline=(255, 255, 255, 90),
            width=1,
        )
        draw.text((chip_x + 20, 398), label, font=chip_font, fill=(255, 255, 255))
        chip_x += chip_w + 14


def main() -> None:
    image = build_background()
    add_icon(image)
    draw_text(image)
    image.convert("RGB").save(OUTPUT_PATH, quality=95)
    print(f"wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
