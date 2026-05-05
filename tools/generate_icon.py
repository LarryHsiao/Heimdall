"""Generate Heimdall's source app icon at assets/app_icon.png.

Drawn by hand: a Material rounded indigo square with three cream cards
offset diagonally — a stacked ticket queue, each card bearing a gold bar
suggesting a ticket title. Renders supersampled at 2048 px and downsamples
to 1024 px with Lanczos for clean edges.

Run from the project root:
    python tools/generate_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SOURCE = 2048
TARGET = 1024

INDIGO = (63, 81, 181, 255)
INDIGO_DEEP = (26, 35, 126, 255)
CREAM = (232, 234, 246, 255)
GOLD = (255, 196, 0, 255)
WHITE = (255, 255, 255, 255)


def render(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    radius = int(size * 0.22)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=INDIGO)

    card_w = int(size * 0.56)
    card_h = int(size * 0.22)
    card_radius = int(size * 0.05)

    dx = int(size * 0.04)
    dy = int(size * 0.13)

    total_w = card_w + 2 * dx
    total_h = card_h + 2 * dy
    start_x = (size - total_w) // 2
    start_y = (size - total_h) // 2

    bar_h = int(card_h * 0.20)
    bar_x_pad = int(card_w * 0.14)

    for i in range(3):
        x = start_x + i * dx
        y = start_y + i * dy

        d.rounded_rectangle(
            (x, y, x + card_w, y + card_h),
            radius=card_radius,
            fill=CREAM,
        )

        bar_y = y + int(card_h * 0.28)
        d.rounded_rectangle(
            (x + bar_x_pad, bar_y, x + card_w - bar_x_pad, bar_y + bar_h),
            radius=bar_h // 2,
            fill=GOLD,
        )

    return img


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "assets" / "app_icon.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    img = render(SOURCE).resize((TARGET, TARGET), Image.LANCZOS)
    img.save(out)
    print(f"Wrote {out} ({TARGET}x{TARGET})")


if __name__ == "__main__":
    main()
