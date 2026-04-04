from pathlib import Path
import os
import textwrap

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]

OUTPUT_SPECS = [
    {
        "output_dir": ROOT / "docs" / "store_assets" / "phone_screenshots",
        "canvas_size": (1080, 1920),
        "device_frame": (256, 600, 824, 1828),
        "border": 14,
        "radius": 44,
        "eyebrow_y": 90,
        "title_y": 155,
        "max_text_width": 920,
        "bubble_row_y": 600,
        "bubble_scale": 1.0,
    },
    {
        "output_dir": ROOT / "docs" / "store_assets" / "tablet_7in_screenshots",
        "canvas_size": (1200, 1920),
        "device_frame": (322, 540, 878, 1816),
        "border": 14,
        "radius": 42,
        "eyebrow_y": 82,
        "title_y": 146,
        "max_text_width": 980,
        "bubble_row_y": 560,
        "bubble_scale": 1.05,
    },
    {
        "output_dir": ROOT / "docs" / "store_assets" / "tablet_10in_screenshots",
        "canvas_size": (1600, 2560),
        "device_frame": (440, 760, 1160, 2390),
        "border": 18,
        "radius": 52,
        "eyebrow_y": 124,
        "title_y": 210,
        "max_text_width": 1260,
        "bubble_row_y": 780,
        "bubble_scale": 1.35,
    },
]

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


def mix(c1, c2, t: float):
    return tuple(round(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_gradient_background(image: Image.Image, spec: dict[str, object]) -> None:
    draw = ImageDraw.Draw(image)
    width, height = image.size
    for y in range(height):
        t = y / (height - 1)
        left = mix((220, 250, 245), (238, 227, 255), t)
        right = mix((227, 229, 255), (217, 184, 255), t)
        for x in range(width):
            draw.point((x, y), fill=mix(left, right, x / (width - 1)))

    bubble_y = spec["bubble_row_y"]
    bubble_scale = spec["bubble_scale"]
    for x_ratio, y_offset, r in [
        (0.08, 0, 40),
        (0.22, 30, 32),
        (0.39, 20, 44),
        (0.56, -5, 48),
        (0.74, 10, 38),
        (0.92, 25, 42),
    ]:
        x = round(width * x_ratio)
        y = round(bubble_y + y_offset * bubble_scale)
        r = round(r * bubble_scale)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 120))


def draw_centered_wrapped_text(
    draw: ImageDraw.ImageDraw,
    canvas_width: int,
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
        ((canvas_width - text_width) / 2, y),
        wrapped,
        font=font,
        fill=fill,
        spacing=spacing,
        align="center",
    )
    return y + text_height


def draw_header(
    image: Image.Image,
    spec: dict[str, object],
    eyebrow: str,
    title: str,
    subtitle: str,
) -> None:
    draw = ImageDraw.Draw(image)
    canvas_width, _ = image.size
    eyebrow_font = load_font(round(canvas_width * 0.020), bold=True)
    title_font = load_font(round(canvas_width * 0.052), bold=True)
    subtitle_font = load_font(round(canvas_width * 0.026))

    eyebrow_box = draw.textbbox((0, 0), eyebrow.upper(), font=eyebrow_font)
    eyebrow_width = eyebrow_box[2] - eyebrow_box[0]
    draw.text(
        ((canvas_width - eyebrow_width) / 2, spec["eyebrow_y"]),
        eyebrow.upper(),
        font=eyebrow_font,
        fill=PRIMARY,
    )
    title_bottom = draw_centered_wrapped_text(
        draw,
        canvas_width,
        spec["title_y"],
        title,
        title_font,
        INK,
        spec["max_text_width"],
        spacing=12,
    )
    draw_centered_wrapped_text(
        draw,
        canvas_width,
        title_bottom + 24,
        subtitle,
        subtitle_font,
        MUTED,
        spec["max_text_width"],
        spacing=10,
    )


def build_phone_layer(
    spec: dict[str, object],
    source_path: Path,
    erase_rects: list[tuple[int, int, int, int]] | None = None,
) -> Image.Image:
    screenshot = Image.open(source_path).convert("RGBA")
    if erase_rects:
        source_draw = ImageDraw.Draw(screenshot)
        for rect in erase_rects:
            source_draw.rectangle(rect, fill=(247, 245, 252, 255))

    device_frame = spec["device_frame"]
    frame_w = device_frame[2] - device_frame[0]
    frame_h = device_frame[3] - device_frame[1]
    border = spec["border"]
    radius = spec["radius"]

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
    spec: dict[str, object],
    source_path: Path,
    erase_rects: list[tuple[int, int, int, int]] | None = None,
) -> None:
    device_frame = spec["device_frame"]
    phone = build_phone_layer(spec, source_path, erase_rects=erase_rects)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_alpha = phone.getchannel("A").point(lambda value: round(value * 0.42))
    shadow_layer = Image.new("RGBA", phone.size, (49, 46, 129, 0))
    shadow_layer.putalpha(shadow_alpha)
    shadow.paste(
        shadow_layer,
        (device_frame[0], device_frame[1] + 24),
        shadow_layer,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(32))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(phone, dest=(device_frame[0], device_frame[1]))


def render_scene(spec: dict[str, object], scene: dict[str, object]) -> None:
    output_dir = spec["output_dir"]
    canvas = Image.new("RGBA", spec["canvas_size"], WHITE)
    draw_gradient_background(canvas, spec)
    draw_header(
        canvas,
        spec,
        scene["eyebrow"],
        scene["title"],
        scene["subtitle"],
    )
    paste_phone(
        canvas,
        spec,
        scene["source"],
        erase_rects=scene.get("erase_rects"),
    )

    output_path = output_dir / scene["output"]
    canvas.convert("RGB").save(output_path, quality=95)
    print(f"wrote {output_path}")


def main() -> None:
    for spec in OUTPUT_SPECS:
        spec["output_dir"].mkdir(parents=True, exist_ok=True)

    for scene in SCENES:
        if not scene["source"].exists():
            raise FileNotFoundError(f"Missing screenshot: {scene['source']}")
        for spec in OUTPUT_SPECS:
            render_scene(spec, scene)


if __name__ == "__main__":
    main()
