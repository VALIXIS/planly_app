from pathlib import Path
import os
import textwrap

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "docs" / "store_assets" / "phone_screenshots"
SCREEN_SIZE = (1080, 1920)
PHONE_FRAME = (256, 600, 824, 1828)

PRIMARY = (124, 77, 255)
INK = (24, 24, 27)
MUTED = (82, 82, 91)
WHITE = (255, 255, 255)

SCENES = [
    {
        "output": "01_home_tasks.png",
        "source": Path(r"c:\Users\nagas\Downloads\Phone Link\Screenshot_20260404_182703.jpg"),
        "eyebrow": "Home Screen",
        "title": "Plan your day with smart groups",
        "subtitle": "See suggested tasks, daily quotes, streaks, Focus Mode, and smart sections like Now and Later Today.",
    },
    {
        "output": "02_calendar_view.png",
        "source": Path(r"c:\Users\nagas\Downloads\Phone Link\Screenshot_20260404_182743.jpg"),
        "erase_rects": [(0, 1960, 1080, 2215)],
        "eyebrow": "Calendar",
        "title": "Check tasks date by date",
        "subtitle": "Browse your monthly calendar and open each day's task list with due time and category details.",
    },
    {
        "output": "03_focus_mode.png",
        "source": Path(r"c:\Users\nagas\Downloads\Phone Link\Screenshot_20260404_182731.jpg"),
        "eyebrow": "Focus Mode",
        "title": "Finish one task at a time",
        "subtitle": "Stay focused with a simple task view, progress indicator, and quick Mark as Done, Skip, or Exit actions.",
    },
    {
        "output": "04_add_task.png",
        "source": Path(r"c:\Users\nagas\Downloads\Phone Link\Screenshot_20260404_182719.jpg"),
        "eyebrow": "Add Task",
        "title": "Create tasks with schedule and repeat",
        "subtitle": "Add a title and notes, set date and time, choose quick dates, and configure repeat options.",
    },
    {
        "output": "05_reminders.png",
        "source": Path(r"c:\Users\nagas\Downloads\Phone Link\Screenshot_20260404_182723.jpg"),
        "eyebrow": "Reminders",
        "title": "Get notified before each deadline",
        "subtitle": "Enable reminders, choose 5m, 10m, 30m, or 60m before, and preview the exact reminder time.",
    },
    {
        "output": "06_settings.png",
        "source": Path(r"c:\Users\nagas\Downloads\Phone Link\Screenshot_20260404_182752.jpg"),
        "erase_rects": [(0, 2060, 1080, 2400)],
        "eyebrow": "Settings",
        "title": "Customize Planly your way",
        "subtitle": "Switch Dark Mode, pick accent colors, and control launch-screen and home-screen quotes.",
    },
]


def load_font(size: int, *, bold: bool = False):
    windir = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"
    candidates = [
        windir / ("segoeuib.ttf" if bold else "segoeui.ttf"),
        windir / ("arialbd.ttf" if bold else "arial.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


FONT_EYEBROW = load_font(22, bold=True)
FONT_TITLE = load_font(56, bold=True)
FONT_SUBTITLE = load_font(28)


def mix(c1, c2, t: float):
    return tuple(round(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_gradient_background(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    width, height = SCREEN_SIZE
    for y in range(height):
        t = y / (height - 1)
        left = mix((220, 250, 245), (238, 227, 255), t)
        right = mix((227, 229, 255), (217, 184, 255), t)
        for x in range(width):
            draw.point((x, y), fill=mix(left, right, x / (width - 1)))

    for x, y, r in [
        (80, 590, 40),
        (220, 620, 32),
        (390, 610, 44),
        (560, 585, 48),
        (740, 600, 38),
        (920, 615, 42),
    ]:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 120))


def draw_centered_wrapped_text(
    draw: ImageDraw.ImageDraw,
    y: int,
    text: str,
    font: ImageFont.ImageFont,
    fill,
    max_width: int,
    spacing: int = 10,
) -> int:
    words_per_line = max(12, int(max_width / (font.size * 0.58)))
    wrapped = textwrap.fill(text, width=words_per_line)
    bbox = draw.multiline_textbbox(
        (0, 0),
        wrapped,
        font=font,
        spacing=spacing,
        align="center",
    )
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    draw.multiline_text(
        ((SCREEN_SIZE[0] - text_width) / 2, y),
        wrapped,
        font=font,
        fill=fill,
        spacing=spacing,
        align="center",
    )
    return y + text_height


def draw_header(image: Image.Image, eyebrow: str, title: str, subtitle: str) -> None:
    draw = ImageDraw.Draw(image)
    eyebrow_box = draw.textbbox((0, 0), eyebrow.upper(), font=FONT_EYEBROW)
    eyebrow_width = eyebrow_box[2] - eyebrow_box[0]
    draw.text(
        ((SCREEN_SIZE[0] - eyebrow_width) / 2, 90),
        eyebrow.upper(),
        font=FONT_EYEBROW,
        fill=PRIMARY,
    )
    title_bottom = draw_centered_wrapped_text(
        draw,
        155,
        title,
        FONT_TITLE,
        INK,
        900,
        spacing=12,
    )
    draw_centered_wrapped_text(
        draw,
        title_bottom + 24,
        subtitle,
        FONT_SUBTITLE,
        MUTED,
        920,
        spacing=10,
    )


def build_phone_layer(
    source_path: Path,
    erase_rects: list[tuple[int, int, int, int]] | None = None,
) -> Image.Image:
    screenshot = Image.open(source_path).convert("RGBA")
    if erase_rects:
        source_draw = ImageDraw.Draw(screenshot)
        for rect in erase_rects:
            source_draw.rectangle(rect, fill=(247, 245, 252, 255))

    frame_w = PHONE_FRAME[2] - PHONE_FRAME[0]
    frame_h = PHONE_FRAME[3] - PHONE_FRAME[1]
    border = 14
    radius = 44

    inner_size = (frame_w - border * 2, frame_h - border * 2)
    screenshot = ImageOps.fit(
        screenshot,
        inner_size,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )

    phone = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    phone_draw = ImageDraw.Draw(phone)
    phone_draw.rounded_rectangle(
        (0, 0, frame_w - 1, frame_h - 1),
        radius=radius,
        fill=(28, 30, 42, 255),
    )
    phone_draw.rounded_rectangle(
        (border, border, frame_w - border - 1, frame_h - border - 1),
        radius=radius - 10,
        fill=WHITE,
    )

    mask = Image.new("L", inner_size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, inner_size[0] - 1, inner_size[1] - 1),
        radius=radius - 10,
        fill=255,
    )
    phone.paste(screenshot, (border, border), mask)
    return phone


def paste_phone(
    canvas: Image.Image,
    source_path: Path,
    erase_rects: list[tuple[int, int, int, int]] | None = None,
) -> None:
    phone = build_phone_layer(source_path, erase_rects=erase_rects)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_alpha = phone.getchannel("A").point(lambda value: round(value * 0.42))
    shadow_layer = Image.new("RGBA", phone.size, (49, 46, 129, 0))
    shadow_layer.putalpha(shadow_alpha)
    shadow.paste(shadow_layer, (PHONE_FRAME[0], PHONE_FRAME[1] + 24), shadow_layer)
    shadow = shadow.filter(ImageFilter.GaussianBlur(32))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(phone, dest=(PHONE_FRAME[0], PHONE_FRAME[1]))


def render_scene(scene: dict[str, object]) -> None:
    canvas = Image.new("RGBA", SCREEN_SIZE, WHITE)
    draw_gradient_background(canvas)
    draw_header(
        canvas,
        scene["eyebrow"],
        scene["title"],
        scene["subtitle"],
    )
    paste_phone(canvas, scene["source"], erase_rects=scene.get("erase_rects"))

    output_path = OUTPUT_DIR / scene["output"]
    canvas.convert("RGB").save(output_path, quality=95)
    print(f"wrote {output_path}")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for scene in SCENES:
        if not scene["source"].exists():
            raise FileNotFoundError(f"Missing screenshot: {scene['source']}")
        render_scene(scene)


if __name__ == "__main__":
    main()
