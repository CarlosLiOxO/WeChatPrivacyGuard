from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Packaging" / "DMGBackground.png"

WIDTH = 820
HEIGHT = 560
SCALE = 2

INK = "#17242E"
MUTED = "#5D6B75"
LINE = "#DCE5EA"
BLUE = "#78AFC4"
BLUE_DARK = "#397D98"
TEAL = "#68AE9A"
TEAL_DARK = "#317E6B"
PALE_BLUE = "#E8F3F7"
PALE_TEAL = "#E7F4F0"
CARD = "#FFFFFF"
WARNING = "#C88245"

FONT_LIGHT = "/System/Library/Fonts/STHeiti Light.ttc"
FONT_MEDIUM = "/System/Library/Fonts/STHeiti Medium.ttc"


def font(size, medium=False):
    return ImageFont.truetype(FONT_MEDIUM if medium else FONT_LIGHT, size * SCALE)


def box(coords):
    return tuple(int(value * SCALE) for value in coords)


def rounded(draw, coords, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(
        box(coords),
        radius=radius * SCALE,
        fill=fill,
        outline=outline,
        width=width * SCALE,
    )


def label(draw, xy, value, size, fill=INK, anchor="la", medium=False):
    draw.text(box(xy), value, font=font(size, medium), fill=fill, anchor=anchor)


def centered_lines(draw, center_x, start_y, lines, size, fill=MUTED, leading=18):
    for index, line in enumerate(lines):
        label(draw, (center_x, start_y + index * leading), line, size, fill, "ma")


def draw_arrow(draw, x1, y, x2):
    draw.line(box((x1, y, x2, y)), fill=BLUE_DARK, width=3 * SCALE)
    draw.line(box((x2 - 10, y - 8, x2, y)), fill=BLUE_DARK, width=3 * SCALE)
    draw.line(box((x2 - 10, y + 8, x2, y)), fill=BLUE_DARK, width=3 * SCALE)


def draw_step(draw, x, number, title, lines, accent):
    rounded(draw, (x, 302, x + 174, 454), 15, CARD, LINE)
    draw.ellipse(box((x + 15, 317, x + 43, 345)), fill=accent)
    label(draw, (x + 29, 331), str(number), 12, CARD, "mm", True)
    label(draw, (x + 52, 331), title, 13, INK, "lm", True)

    if number == 1:
        rounded(draw, (x + 17, 360, x + 157, 402), 10, "#F7F9FA", LINE)
        draw.polygon(
            [box((x + 36, 370)), box((x + 25, 391)), box((x + 47, 391))],
            fill="#E9B56F",
        )
        label(draw, (x + 91, 376), "无法验证开发者", 9, INK, "ma")
        rounded(draw, (x + 91, 387, x + 140, 399), 6, "#E9EDF0")
        label(draw, (x + 115, 393), "完成", 7, MUTED, "mm")
    elif number == 2:
        rounded(draw, (x + 17, 360, x + 157, 402), 10, "#F7F9FA", LINE)
        rounded(draw, (x + 28, 370, x + 49, 391), 5, PALE_BLUE)
        label(draw, (x + 38, 381), "⌁", 13, BLUE_DARK, "mm", True)
        label(draw, (x + 60, 376), "隐私与安全性", 9, INK, "la")
        label(draw, (x + 60, 390), "向下滚动", 7, MUTED, "la")
    elif number == 3:
        rounded(draw, (x + 17, 360, x + 157, 402), 10, "#F7F9FA", LINE)
        label(draw, (x + 28, 376), "微信隐私守卫", 8, INK, "la")
        rounded(draw, (x + 89, 383, x + 145, 398), 7, PALE_TEAL, TEAL)
        label(draw, (x + 117, 390), "仍要打开", 7, TEAL_DARK, "mm", True)
    else:
        rounded(draw, (x + 17, 360, x + 157, 402), 10, "#F7F9FA", LINE)
        label(draw, (x + 87, 374), "确认打开？", 9, INK, "ma")
        rounded(draw, (x + 88, 383, x + 144, 399), 7, TEAL)
        label(draw, (x + 116, 391), "打开", 7, CARD, "mm", True)

    centered_lines(draw, x + 87, 420, lines, 8.5, MUTED, 15)


def build():
    image = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), "#F5F8FA")
    pixels = image.load()
    top = (237, 244, 247)
    bottom = (250, 252, 253)
    for y in range(HEIGHT * SCALE):
        ratio = y / max(1, HEIGHT * SCALE - 1)
        row = tuple(round(top[i] * (1 - ratio) + bottom[i] * ratio) for i in range(3))
        for x in range(WIDTH * SCALE):
            pixels[x, y] = row

    draw = ImageDraw.Draw(image)

    # Brand header.
    label(draw, (36, 43), "微信隐私守卫", 22, INK, "la", True)
    label(draw, (37, 70), "安装与首次打开", 11, MUTED)
    rounded(draw, (648, 42, 784, 72), 15, PALE_TEAL)
    label(draw, (716, 57), "本机识别 · 不上传", 10, TEAL_DARK, "mm", True)

    # Installation area. The circles are guides; Finder places the real items on top.
    rounded(draw, (36, 86, 784, 276), 19, "#FFFFFFCC", "#D6E4EA")
    draw.ellipse(box((145, 116, 275, 246)), fill=PALE_BLUE, outline=BLUE, width=2 * SCALE)
    draw.ellipse(box((545, 116, 675, 246)), fill=PALE_TEAL, outline=TEAL, width=2 * SCALE)
    label(draw, (210, 106), "① 微信隐私守卫", 11, BLUE_DARK, "ma", True)
    label(draw, (610, 106), "② Applications", 11, TEAL_DARK, "ma", True)
    draw_arrow(draw, 313, 181, 507)
    label(draw, (410, 163), "拖到右侧", 13, INK, "ma", True)
    label(draw, (410, 202), "复制完成后，从“应用程序”打开", 9.5, MUTED, "ma")

    label(draw, (36, 288), "首次打开被拦截？按下面 4 步放行", 14, INK, "la", True)
    steps = [
        (36, 1, "首次打开", ["看到警告后", "点击“完成”"], BLUE),
        (226, 2, "进入设置", ["系统设置 →", "隐私与安全性"], BLUE),
        (416, 3, "允许来源", ["找到 App", "点击“仍要打开”"], TEAL),
        (606, 4, "再次确认", ["点击“打开”", "可能需密码"], TEAL),
    ]
    for step in steps:
        draw_step(draw, *step)

    rounded(draw, (36, 476, 610, 538), 15, "#F2F7F9", "#D6E4EA")
    draw.ellipse(box((52, 492, 76, 516)), fill="#FBEEDC")
    label(draw, (64, 504), "!", 13, WARNING, "mm", True)
    label(draw, (88, 493), "安全提醒", 10.5, INK, "la", True)
    label(draw, (88, 515), "本版本已完成本地测试与完整性校验。", 9, MUTED)
    label(draw, (657, 491), "需要完整图解？", 9.5, MUTED, "ma")
    label(draw, (657, 508), "打开右侧 PDF →", 9.5, TEAL_DARK, "ma", True)

    image = image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, "PNG", optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    build()
