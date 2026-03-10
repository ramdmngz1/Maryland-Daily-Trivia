from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
from pathlib import Path

OUT = Path('/Users/ramondominguez/Desktop/Apps/Maryland-Daily-Trivia/Documents/App-Icon-Mockups')
SIZE = 1024
CENTER = SIZE // 2


def radial_bg(inner=(37, 12, 6), outer=(6, 4, 10), noise=False):
    img = Image.new('RGB', (SIZE, SIZE), outer)
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            dx = (x - CENTER) / SIZE
            dy = (y - CENTER) / SIZE
            r = (dx * dx + dy * dy) ** 0.5
            t = max(0.0, 1.0 - min(1.0, r * 1.95))
            rr = int(outer[0] + (inner[0] - outer[0]) * t)
            gg = int(outer[1] + (inner[1] - outer[1]) * t)
            bb = int(outer[2] + (inner[2] - outer[2]) * t)
            px[x, y] = (rr, gg, bb)
    if noise:
        layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for gx in range(32, SIZE, 40):
            d.line([(gx, 0), (gx, SIZE)], fill=(255, 160, 60, 12), width=1)
        return Image.alpha_composite(img.convert('RGBA'), layer).convert('RGB')
    return img


def glow_line(draw, points, color=(255, 186, 52), width=10, glow=22):
    glow_img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_img)
    gd.line(points, fill=color + (175,), width=width)
    for blur in (glow, glow // 2):
        blur_img = glow_img.filter(ImageFilter.GaussianBlur(blur))
        base.alpha_composite(blur_img)
    draw.line(points, fill=color + (255,), width=max(2, width - 3))


def shield_path(x, y, w, h):
    pts = []
    r = w * 0.15
    steps = 16
    for i in range(steps + 1):
        a = math.pi + (math.pi / 2) * (i / steps)
        pts.append((x + r + r * math.cos(a), y + r + r * math.sin(a)))
    for i in range(steps + 1):
        a = -math.pi / 2 + (math.pi / 2) * (i / steps)
        pts.append((x + w - r + r * math.cos(a), y + r + r * math.sin(a)))
    pts.append((x + w, y + h * 0.68))
    pts.append((x + w * 0.5, y + h))
    pts.append((x, y + h * 0.68))
    return pts


def star(cx, cy, r1, r2, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def save(name):
    p = OUT / name
    base.convert('RGB').save(p)
    return p


def draw_crab_icon(draw, cx, cy, scale, color=(255, 186, 52)):
    # Body
    body_w = int(260 * scale)
    body_h = int(140 * scale)
    body = [
        (cx - body_w // 2, cy),
        (cx - int(body_w * 0.32), cy - body_h),
        (cx + int(body_w * 0.32), cy - body_h),
        (cx + body_w // 2, cy),
        (cx + int(body_w * 0.18), cy + int(body_h * 0.35)),
        (cx - int(body_w * 0.18), cy + int(body_h * 0.35)),
    ]
    poly = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    pd = ImageDraw.Draw(poly)
    pd.polygon(body, outline=color + (255,), width=max(4, int(8 * scale)))
    glow = poly.filter(ImageFilter.GaussianBlur(12 * scale))
    base.alpha_composite(glow)
    base.alpha_composite(poly)

    # Legs
    for s in (-1, 1):
        for i in range(3):
            x1 = cx + s * int((35 + i * 35) * scale)
            y1 = cy + int((35 + i * 5) * scale)
            x2 = cx + s * int((90 + i * 40) * scale)
            y2 = cy + int((95 + i * 18) * scale)
            glow_line(draw, [(x1, y1), (x2, y2)], color=color, width=max(4, int(8 * scale)), glow=max(8, int(14 * scale)))

    # Eyes
    for s in (-1, 1):
        glow_line(draw, [(cx + s * int(45 * scale), cy - int(80 * scale)), (cx + s * int(45 * scale), cy - int(45 * scale))], color=color, width=max(4, int(6 * scale)), glow=max(8, int(12 * scale)))
        dot = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        dd = ImageDraw.Draw(dot)
        r = int(8 * scale)
        ex = cx + s * int(45 * scale)
        ey = cy - int(84 * scale)
        dd.ellipse((ex - r, ey - r, ex + r, ey + r), fill=color + (255,))
        base.alpha_composite(dot.filter(ImageFilter.GaussianBlur(max(4, int(7 * scale)))))
        base.alpha_composite(dot)

    # Claws
    for s in (-1, 1):
        elbow = (cx + s * int(170 * scale), cy - int(90 * scale))
        shoulder = (cx + s * int(110 * scale), cy - int(35 * scale))
        glow_line(draw, [shoulder, elbow], color=color, width=max(4, int(9 * scale)), glow=max(8, int(15 * scale)))
        c = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        cd = ImageDraw.Draw(c)
        px, py = elbow
        claw = [
            (px, py),
            (px + s * int(48 * scale), py - int(28 * scale)),
            (px + s * int(60 * scale), py - int(6 * scale)),
            (px + s * int(28 * scale), py + int(4 * scale)),
            (px + s * int(50 * scale), py + int(36 * scale)),
            (px + s * int(26 * scale), py + int(42 * scale)),
        ]
        cd.line(claw, fill=color + (255,), width=max(4, int(8 * scale)), joint='curve')
        base.alpha_composite(c.filter(ImageFilter.GaussianBlur(max(8, int(12 * scale)))))
        base.alpha_composite(c)


# --------- Icon 1: Maryland Crest Shield ---------
base = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))
base.alpha_composite(radial_bg((39, 12, 8), (7, 5, 10), noise=True).convert('RGBA'))
d = ImageDraw.Draw(base)

outer = shield_path(130, 120, 764, 800)
inner = shield_path(168, 165, 688, 710)

for w, blur, a in [(18, 26, 120), (12, 14, 150)]:
    layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.line(outer + [outer[0]], fill=(255, 182, 55, a), width=w, joint='curve')
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))

d.line(outer + [outer[0]], fill=(255, 186, 52, 255), width=9, joint='curve')
d.line(inner + [inner[0]], fill=(150, 92, 23, 170), width=3, joint='curve')

# subtle quartered Maryland-inspired fill
fill_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
fd = ImageDraw.Draw(fill_layer)
fd.polygon(inner, fill=(18, 10, 16, 120))
clip = Image.new('L', (SIZE, SIZE), 0)
ImageDraw.Draw(clip).polygon(inner, fill=255)
pattern = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
pd = ImageDraw.Draw(pattern)
for y in range(180, 860, 34):
    pd.line([(220, y), (804, y)], fill=(255, 210, 96, 20), width=1)
# red-white crosses (simplified)
pd.rectangle((250, 260, 500, 480), fill=(132, 18, 24, 95))
pd.rectangle((520, 260, 770, 480), fill=(16, 16, 18, 95))
pd.rectangle((250, 500, 500, 720), fill=(16, 16, 18, 95))
pd.rectangle((520, 500, 770, 720), fill=(132, 18, 24, 95))
pattern.putalpha(clip)
base.alpha_composite(fill_layer)
base.alpha_composite(pattern)

draw_crab_icon(d, CENTER, 560, 1.05)

# top star and text
s = star(CENTER, 205, 92, 38)
star_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(star_layer)
sd.polygon(s, fill=(239, 188, 74, 255), outline=(190, 123, 25, 255))
base.alpha_composite(star_layer.filter(ImageFilter.GaussianBlur(10)))
base.alpha_composite(star_layer)

try:
    font_big = ImageFont.truetype('/System/Library/Fonts/Supplemental/Georgia Bold.ttf', 84)
    font_small = ImageFont.truetype('/System/Library/Fonts/Supplemental/Georgia Bold.ttf', 62)
except OSError:
    font_big = ImageFont.load_default()
    font_small = ImageFont.load_default()

txt = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
td = ImageDraw.Draw(txt)
label_top = 'MARYLAND'
label_bottom = 'TRIVIA'
b1 = td.textbbox((0, 0), label_top, font=font_small)
b2 = td.textbbox((0, 0), label_bottom, font=font_big)
w1 = b1[2] - b1[0]
w2 = b2[2] - b2[0]
td.text((CENTER - w1 // 2, 676), label_top, font=font_small, fill=(255, 233, 178, 235))
td.text((CENTER - w2 // 2, 736), label_bottom, font=font_big, fill=(255, 206, 92, 245))
base.alpha_composite(txt.filter(ImageFilter.GaussianBlur(8)))
base.alpha_composite(txt)

save('maryland-icon-mockup-1.png')

# --------- Icon 2: Flag + Question Crest ---------
base = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))
base.alpha_composite(radial_bg((30, 9, 8), (6, 4, 10), noise=False).convert('RGBA'))
d = ImageDraw.Draw(base)

# Shield
outer = shield_path(140, 120, 744, 790)
inner = shield_path(180, 160, 664, 710)
for w, blur, a in [(20, 24, 130), (12, 12, 170)]:
    layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.line(outer + [outer[0]], fill=(250, 181, 58, a), width=w)
    base.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
d.line(outer + [outer[0]], fill=(250, 181, 58, 255), width=10)

# Maryland quarter motif in shield
clip = Image.new('L', (SIZE, SIZE), 0)
ImageDraw.Draw(clip).polygon(inner, fill=255)
flag = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
fd = ImageDraw.Draw(flag)
ix1, iy1 = 220, 210
ix2, iy2 = 804, 780
mx = (ix1 + ix2) // 2
my = (iy1 + iy2) // 2

# Quadrants
fd.rectangle((ix1, iy1, mx, my), fill=(20, 20, 24, 190))
fd.rectangle((mx, iy1, ix2, my), fill=(126, 17, 21, 195))
fd.rectangle((ix1, my, mx, iy2), fill=(126, 17, 21, 195))
fd.rectangle((mx, my, ix2, iy2), fill=(20, 20, 24, 190))

# Yellow check bars
for y in range(iy1 + 8, my, 28):
    fd.rectangle((ix1, y, mx, y + 13), fill=(242, 187, 72, 170))
for y in range(my + 8, iy2, 28):
    fd.rectangle((mx, y, ix2, y + 13), fill=(242, 187, 72, 170))

# White cross strokes
for i in range(8):
    yy = iy1 + i * 36
    fd.line((mx + 12, yy, ix2 - 10, yy + 26), fill=(240, 232, 220, 95), width=5)
for i in range(8):
    yy = my + i * 36
    fd.line((ix1 + 10, yy, mx - 10, yy + 26), fill=(240, 232, 220, 95), width=5)

flag.putalpha(clip)
base.alpha_composite(flag)

# central question mark neon
try:
    font_q = ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf', 360)
    font_md = ImageFont.truetype('/System/Library/Fonts/Supplemental/Georgia Bold.ttf', 78)
except OSError:
    font_q = ImageFont.load_default()
    font_md = ImageFont.load_default()

q_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
qd = ImageDraw.Draw(q_layer)
q = '?'
bbq = qd.textbbox((0, 0), q, font=font_q)
qw = bbq[2] - bbq[0]
qd.text((CENTER - qw // 2, 352), q, font=font_q, fill=(255, 219, 123, 255))
l1 = 'MARYLAND'
l2 = 'MD'
bb1 = qd.textbbox((0, 0), l1, font=font_md)
bb2 = qd.textbbox((0, 0), l2, font=font_md)
qd.text((CENTER - (bb1[2] - bb1[0]) // 2, 706), l1, font=font_md, fill=(255, 232, 168, 240))
qd.text((CENTER - (bb2[2] - bb2[0]) // 2, 778), l2, font=font_md, fill=(255, 188, 84, 230))
base.alpha_composite(q_layer.filter(ImageFilter.GaussianBlur(12)))
base.alpha_composite(q_layer)

s = star(CENTER, 176, 86, 34)
st = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(st).polygon(s, fill=(242, 191, 77, 255))
base.alpha_composite(st.filter(ImageFilter.GaussianBlur(10)))
base.alpha_composite(st)

save('maryland-icon-mockup-2.png')

# --------- Icon 3: Neon Crab Badge (minimal) ---------
base = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))
base.alpha_composite(radial_bg((34, 10, 8), (5, 3, 8), noise=False).convert('RGBA'))
d = ImageDraw.Draw(base)

# Rounded square badge glow
badge = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
bd = ImageDraw.Draw(badge)
bd.rounded_rectangle((165, 165, 859, 859), radius=190, outline=(255, 180, 56, 250), width=12, fill=(17, 8, 12, 165))
base.alpha_composite(badge.filter(ImageFilter.GaussianBlur(18)))
base.alpha_composite(badge)

# Maryland corner accent strips
acc = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
ad = ImageDraw.Draw(acc)
ad.polygon([(165,165),(422,165),(165,422)], fill=(245, 188, 75, 145))
ad.polygon([(859,859),(602,859),(859,602)], fill=(130, 21, 26, 165))
base.alpha_composite(acc.filter(ImageFilter.GaussianBlur(6)))
base.alpha_composite(acc)

# Main crab neon
draw_crab_icon(d, CENTER, 545, 1.28, color=(255, 183, 62))

# small stars + MD
for sx in (360, 664):
    sp = star(sx, 282, 34, 14)
    l = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(l).polygon(sp, fill=(245, 188, 74, 245))
    base.alpha_composite(l.filter(ImageFilter.GaussianBlur(6)))
    base.alpha_composite(l)

try:
    font_md = ImageFont.truetype('/System/Library/Fonts/Supplemental/Georgia Bold.ttf', 132)
except OSError:
    font_md = ImageFont.load_default()

text = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(text).text((CENTER - 95, 710), 'MD', font=font_md, fill=(255, 210, 110, 240))
base.alpha_composite(text.filter(ImageFilter.GaussianBlur(8)))
base.alpha_composite(text)

save('maryland-icon-mockup-3.png')
print('Generated mockups in', OUT)
