from pathlib import Path
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "outputs" / "快速使用指南.pdf"
ICON = ROOT / "Packaging" / "AppIcon-master.png"
FONT_PATH = Path("/System/Library/Fonts/STHeiti Light.ttc")

BG = "#F3F6F8"
CARD = "#FFFFFF"
INK = "#17242E"
MUTED = "#5D6B75"
LINE = "#DCE5EA"
BLUE = "#78AFC4"
BLUE_DARK = "#397D98"
TEAL = "#68AE9A"
TEAL_DARK = "#317E6B"
PALE_BLUE = "#E8F3F7"
PALE_TEAL = "#E7F4F0"
WARNING = "#D69B62"


def register_fonts():
    if not FONT_PATH.exists():
        raise FileNotFoundError(f"找不到系统中文字体：{FONT_PATH}")
    pdfmetrics.registerFont(TTFont("PingFang", str(FONT_PATH), subfontIndex=0))


def color(c, value):
    c.setFillColor(value)
    c.setStrokeColor(value)


def round_rect(c, x, y, w, h, radius=12, fill=CARD, stroke=LINE, line=0.8):
    c.setLineWidth(line)
    c.setFillColor(fill)
    c.setStrokeColor(stroke)
    c.roundRect(x, y, w, h, radius, fill=1, stroke=1)


def text(c, x, y, value, size, fill=INK, align="left"):
    c.setFont("PingFang", size)
    c.setFillColor(fill)
    if align == "center":
        c.drawCentredString(x, y, value)
    elif align == "right":
        c.drawRightString(x, y, value)
    else:
        c.drawString(x, y, value)


def wrapped(c, x, y, lines, size=10.5, fill=MUTED, leading=15):
    for i, line in enumerate(lines):
        text(c, x, y - i * leading, line, size, fill)


def draw_eye(c, cx, cy, w=34, h=17, stroke=BLUE_DARK):
    c.setLineWidth(1.6)
    c.setStrokeColor(stroke)
    p = c.beginPath()
    p.moveTo(cx - w / 2, cy)
    p.curveTo(cx - w / 4, cy + h / 2, cx + w / 4, cy + h / 2, cx + w / 2, cy)
    p.curveTo(cx + w / 4, cy - h / 2, cx - w / 4, cy - h / 2, cx - w / 2, cy)
    c.drawPath(p, stroke=1, fill=0)
    c.setFillColor(TEAL)
    c.circle(cx, cy, 4.2, fill=1, stroke=0)
    c.setFillColor(INK)
    c.circle(cx, cy, 1.7, fill=1, stroke=0)


def draw_face(c, cx, cy, r, fill=PALE_BLUE, stroke=BLUE_DARK, looking=True):
    c.setFillColor(fill)
    c.setStrokeColor(stroke)
    c.setLineWidth(1.2)
    c.circle(cx, cy, r, fill=1, stroke=1)
    eye_shift = 0 if looking else r * 0.28
    c.setFillColor(stroke)
    c.circle(cx - r * 0.30 + eye_shift, cy + r * 0.12, max(1.0, r * 0.08), fill=1, stroke=0)
    c.circle(cx + r * 0.30 + eye_shift, cy + r * 0.12, max(1.0, r * 0.08), fill=1, stroke=0)
    c.setStrokeColor(stroke)
    c.arc(cx - r * 0.30, cy - r * 0.45, cx + r * 0.30, cy + r * 0.02, 200, 140)


def card_header(c, x, y, w, number, title):
    c.setFillColor(PALE_TEAL)
    c.circle(x + 18, y + 264, 11, fill=1, stroke=0)
    text(c, x + 18, y + 259.5, str(number), 11, TEAL_DARK, "center")
    text(c, x + 36, y + 258.5, title, 14, INK)


def draw_install(c, x, y, w):
    ix, iy = x + 18, y + 132
    round_rect(c, ix, iy, 47, 47, 11, PALE_BLUE, BLUE, 1)
    c.setFillColor(TEAL)
    c.circle(ix + 23.5, iy + 25, 12, fill=1, stroke=0)
    draw_eye(c, ix + 23.5, iy + 25, 24, 12, CARD)
    c.setStrokeColor(BLUE_DARK)
    c.setLineWidth(2)
    c.line(ix + 55, iy + 23, ix + 78, iy + 23)
    c.line(ix + 72, iy + 29, ix + 78, iy + 23)
    c.line(ix + 72, iy + 17, ix + 78, iy + 23)
    fx, fy = x + w - 48, iy + 7
    c.setFillColor(PALE_TEAL)
    c.setStrokeColor(TEAL_DARK)
    p = c.beginPath()
    p.moveTo(fx - 24, fy + 31)
    p.lineTo(fx - 8, fy + 31)
    p.lineTo(fx - 3, fy + 37)
    p.lineTo(fx + 24, fy + 37)
    p.lineTo(fx + 24, fy)
    p.lineTo(fx - 24, fy)
    p.close()
    c.drawPath(p, fill=1, stroke=1)
    text(c, x + w / 2, y + 107, "拖入 Applications", 9.5, MUTED, "center")


def draw_permission(c, x, y, w):
    mx, my, mw, mh = x + 20, y + 121, w - 40, 76
    round_rect(c, mx, my, mw, mh, 9, "#F8FAFB", BLUE, 1)
    c.setFillColor(INK)
    c.roundRect(mx, my + mh - 11, mw, 11, 9, fill=1, stroke=0)
    c.setFillColor(TEAL)
    c.circle(mx + mw / 2, my + mh - 5.5, 2.3, fill=1, stroke=0)
    round_rect(c, mx + 14, my + 16, mw - 28, 35, 7, CARD, LINE, 0.7)
    c.setFillColor(PALE_BLUE)
    c.circle(mx + 30, my + 33.5, 9, fill=1, stroke=0)
    c.setStrokeColor(BLUE_DARK)
    c.setLineWidth(1.2)
    c.rect(mx + 25, my + 30, 8, 7, fill=0, stroke=1)
    c.line(mx + 33, my + 35, mx + 37, my + 38)
    text(c, mx + 45, my + 36, "摄像头权限", 8.5, INK)
    c.setFillColor(TEAL)
    c.roundRect(mx + mw - 42, my + 23, 24, 12, 6, fill=1, stroke=0)
    c.setFillColor(CARD)
    c.circle(mx + mw - 24, my + 29, 4, fill=1, stroke=0)


def draw_app_menu(c, x, y, w):
    cx = x + w / 2
    c.setFillColor(INK)
    c.roundRect(cx - 46, y + 184, 92, 18, 5, fill=1, stroke=0)
    draw_eye(c, cx + 28, y + 193, 18, 9, CARD)
    round_rect(c, cx - 48, y + 109, 96, 71, 8, CARD, BLUE, 1)
    rows = [("微信（固定）", True), ("备忘录", True), ("预览", False)]
    for i, (label, checked) in enumerate(rows):
        ry = y + 160 - i * 18
        c.setFillColor(PALE_TEAL if checked else BG)
        c.roundRect(cx - 39, ry - 5, 12, 12, 3, fill=1, stroke=0)
        if checked:
            c.setStrokeColor(TEAL_DARK)
            c.setLineWidth(1.4)
            c.line(cx - 36, ry, cx - 33, ry - 3)
            c.line(cx - 33, ry - 3, cx - 28, ry + 4)
        text(c, cx - 20, ry - 3, label, 8.5, INK)


def draw_settings(c, x, y, w):
    labels = [
        ("保护方式", ["隐藏", "遮罩"], 0),
        ("保护距离", ["近", "标准", "远"], 1),
        ("响应速度", ["快速", "标准", "稳健"], 0),
    ]
    for row, (name, options, selected) in enumerate(labels):
        base_y = y + 178 - row * 43
        text(c, x + 17, base_y + 16, name, 9.0, INK)
        total_w = w - 34
        seg_w = total_w / len(options)
        round_rect(c, x + 17, base_y - 5, total_w, 19, 6, BG, LINE, 0.7)
        for i, label in enumerate(options):
            sx = x + 17 + i * seg_w
            if i == selected:
                c.setFillColor(TEAL)
                c.roundRect(sx + 1, base_y - 4, seg_w - 2, 17, 5, fill=1, stroke=0)
            text(c, sx + seg_w / 2, base_y + 1, label, 8.0, CARD if i == selected else MUTED, "center")


def draw_hide(c, x, y, w):
    gap = 6
    pw = (w - 34 - gap) / 2
    px1, px2, py, ph = x + 14, x + 14 + pw + gap, y + 113, 86
    round_rect(c, px1, py, pw, ph, 7, "#FAFBFC", LINE, 0.8)
    round_rect(c, px2, py, pw, ph, 7, "#E8F0F4", TEAL, 0.8)
    draw_eye(c, px1 + pw / 2, py + 57, 28, 14, BLUE_DARK)
    c.setStrokeColor(WARNING)
    c.setLineWidth(2)
    c.line(px1 + pw / 2 - 13, py + 68, px1 + pw / 2 + 13, py + 46)
    text(c, px1 + pw / 2, py + 20, "隐藏", 8.2, INK, "center")
    text(c, px1 + pw / 2, py + 8, "手动恢复", 7.8, MUTED, "center")
    c.saveState()
    c.setFillAlpha(0.26)
    c.setFillColor(BLUE)
    c.circle(px2 + 16, py + 70, 20, fill=1, stroke=0)
    c.setFillColor(TEAL)
    c.circle(px2 + pw - 12, py + 48, 22, fill=1, stroke=0)
    c.restoreState()
    round_rect(c, px2 + 10, py + 39, pw - 20, 38, 9, "#F8FBFC", "#FFFFFF", 0.8)
    draw_eye(c, px2 + pw / 2, py + 58, 25, 12, BLUE_DARK)
    text(c, px2 + pw / 2, py + 20, "遮罩", 8.2, TEAL_DARK, "center")
    text(c, px2 + pw / 2, py + 8, "自动恢复", 7.8, TEAL_DARK, "center")


def build():
    register_fonts()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    width, height = landscape(A4)
    c = canvas.Canvas(str(OUTPUT), pagesize=(width, height), pageCompression=1)
    c.setTitle("微信隐私守卫｜快速使用指南")
    c.setAuthor("微信隐私守卫")

    c.setFillColor(BG)
    c.rect(0, 0, width, height, fill=1, stroke=0)

    c.drawImage(ImageReader(str(ICON)), 34, 498, 60, 60, preserveAspectRatio=True, mask="auto")
    text(c, 111, 532, "微信隐私守卫", 28, INK)
    text(c, 112, 507, "快速使用指南｜检测到可能窥屏的人时，自动隐藏或遮住受保护应用", 12.5, MUTED)
    c.setFillColor(TEAL)
    c.roundRect(width - 147, 522, 112, 25, 12.5, fill=1, stroke=0)
    text(c, width - 91, 529.5, "本机识别 · 不上传", 10, CARD, "center")

    margin, gap, card_y, card_h = 34, 10, 182, 295
    card_w = (width - margin * 2 - gap * 4) / 5
    for i in range(4):
        ax = margin + (i + 1) * card_w + i * gap + gap / 2
        c.setStrokeColor(BLUE)
        c.setLineWidth(1.2)
        c.line(ax - 5, card_y + 151, ax + 5, card_y + 151)
        c.line(ax + 1, card_y + 155, ax + 5, card_y + 151)
        c.line(ax + 1, card_y + 147, ax + 5, card_y + 151)

    titles = ["安装应用", "允许摄像头", "选择额外应用", "调整保护策略", "触发与恢复"]
    bodies = [
        ["拖入“应用程序”，", "然后首次打开。"],
        ["只统计本机画面中的人脸，", "不保存或上传。"],
        ["微信固定保护，还可以", "再选择一个应用。"],
        ["方式：隐藏／遮罩", "距离和速度也可调整。"],
        ["隐藏需手动恢复；遮罩在", "风险消失 1 秒后自动恢复。"],
    ]
    illustrators = [draw_install, draw_permission, draw_app_menu, draw_settings, draw_hide]

    for i in range(5):
        x = margin + i * (card_w + gap)
        round_rect(c, x, card_y, card_w, card_h, 14, CARD, LINE, 0.8)
        card_header(c, x, card_y, card_w, i + 1, titles[i])
        illustrators[i](c, x, card_y, card_w)
        c.setStrokeColor(LINE)
        c.setLineWidth(0.7)
        c.line(x + 14, card_y + 73, x + card_w - 14, card_y + 73)
        wrapped(c, x + 14, card_y + 47, bodies[i], 10.5, MUTED, 16)

    round_rect(c, 34, 30, width - 68, 126, 14, CARD, LINE, 0.8)
    text(c, 53, 127, "使用提示", 13, INK)
    tips = [
        (TEAL, "摄像头分析全部在本机内存中完成。"),
        (BLUE, "摄像头无法证明他人是否真的读清屏幕，保护距离是基于人脸大小和朝向的风险估算。"),
        (WARNING, "如未看到新安装的 App，请在菜单中点击“刷新应用列表”。"),
    ]
    for i, (dot, tip) in enumerate(tips):
        ty = 102 - i * 25
        c.setFillColor(dot)
        c.circle(57, ty + 3, 3.5, fill=1, stroke=0)
        text(c, 69, ty, tip, 10.5, MUTED)

    text(c, width - 42, 42, "v1.3.1", 9.5, BLUE_DARK, "right")
    c.showPage()
    c.save()
    print(OUTPUT)


if __name__ == "__main__":
    build()
