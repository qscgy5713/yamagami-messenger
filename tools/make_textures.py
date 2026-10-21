#!/usr/bin/env python3
"""手繪日式建築貼圖(PIL):障子、瓦、海鼠壁、燒杉板、格子窗、暖簾。原創,無授權問題。
用法:python3 tools/make_textures.py → assets/textures/jp/*.png"""
import os, random, math
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "jp")
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def noisy(img, amount=10):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = px[x, y][:3]
            n = random.randint(-amount, amount)
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    return img

def shoji():
    # 一扇 1 x 2 公尺的障子:和紙 + 木製組子(3 直 × 7 橫格)
    w, h = 256, 512
    img = noisy(Image.new("RGB", (w, h), (246, 240, 224)), 5)
    d = ImageDraw.Draw(img)
    for _ in range(260):  # 和紙纖維
        x, y = random.randint(0, w), random.randint(0, h)
        d.line([x, y, x + random.randint(-14, 14), y + random.randint(-14, 14)], fill=(232, 224, 204), width=1)
    wood, hi = (78, 52, 34), (112, 80, 54)
    for k in range(1, 3):  # 直組子
        x = k * w // 3
        d.rectangle([x - 3, 0, x + 3, h], fill=wood); d.line([x - 3, 0, x - 3, h], fill=hi)
    for k in range(1, 7):  # 橫組子
        y = k * h // 7
        d.rectangle([0, y - 3, w, y + 3], fill=wood); d.line([0, y - 3, w, y - 3], fill=hi)
    d.rectangle([0, 0, w - 1, h - 1], outline=wood, width=14)  # 外框
    d.rectangle([14, 14, w - 15, h - 15], outline=hi, width=1)
    d.rectangle([0, int(h * 0.58), w, int(h * 0.58) + 8], fill=wood)  # 腰板橫木
    img.save(os.path.join(OUT, "shoji.png"))

def kawara():
    # 本瓦葺:平瓦(凹)與丸瓦(凸)交錯成縱向條紋,每片瓦橫向疊壓
    w = h = 512
    img = Image.new("RGB", (w, h), (52, 56, 64))
    d = ImageDraw.Draw(img)
    strip, tile_h = 32, 64
    for c in range(w // strip):
        x0 = c * strip
        for r in range(h // tile_h + 1):
            y0 = r * tile_h
            if c % 2 == 0:  # 平瓦:漸層 + 疊壓處的亮邊
                for yy in range(tile_h):
                    t = yy / tile_h
                    v = int(48 + 26 * t)
                    d.line([x0, y0 + yy, x0 + strip, y0 + yy], fill=(v, v + 4, v + 12))
                d.line([x0, y0 + tile_h - 3, x0 + strip, y0 + tile_h - 3], fill=(120, 126, 138), width=2)
            else:  # 丸瓦:圓筒受光,中央亮、兩側暗
                for xx in range(strip):
                    t = abs((xx - strip / 2) / (strip / 2))
                    v = int(110 - 62 * t ** 1.5)
                    d.line([x0 + xx, y0, x0 + xx, y0 + tile_h], fill=(v, v + 5, v + 14))
                d.ellipse([x0 + 3, y0 + tile_h - 13, x0 + strip - 3, y0 + tile_h + 3], fill=(40, 44, 52), outline=(150, 155, 165))
        d.line([x0, 0, x0, h], fill=(205, 205, 198), width=2)  # 白灰漿縫
    img = noisy(img, 7).filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT, "kawara.png"))

def namako():
    # 海鼠壁:黑色平瓦貼面 + 白灰泥隆起的格縫(土藏的招牌外觀)
    w = h = 512
    img = noisy(Image.new("RGB", (w, h), (40, 44, 52)), 8)
    d = ImageDraw.Draw(img)
    cell = 64
    for i in range(0, w + 1, cell):
        for off, col in ((-5, (150, 148, 140)), (-3, (212, 210, 200)), (0, (238, 236, 228)), (3, (212, 210, 200)), (5, (150, 148, 140))):
            d.line([i + off, 0, i + off, h], fill=col, width=2)
            d.line([0, i + off, w, i + off], fill=col, width=2)
    for _ in range(40):  # 瓦面微光
        x, y = random.randint(0, w), random.randint(0, h)
        d.ellipse([x, y, x + 14, y + 6], fill=(58, 63, 74))
    img.save(os.path.join(OUT, "namako.png"))

def yakisugi():
    # 燒杉板:直向木板、炭化黑色、木紋與板縫
    w = h = 512
    img = Image.new("RGB", (w, h), (28, 26, 24))
    d = ImageDraw.Draw(img)
    board = 64
    for b in range(w // board):
        x0 = b * board
        base = random.randint(26, 40)
        d.rectangle([x0, 0, x0 + board, h], fill=(base, base - 2, base - 4))
        for _ in range(26):
            x = x0 + random.randint(4, board - 4)
            y = random.randint(0, h)
            d.line([x, y, x + random.randint(-2, 2), y + random.randint(40, 160)], fill=(base + 16, base + 12, base + 8), width=1)
        for _ in range(7):  # 炭化龜裂
            x = x0 + random.randint(6, board - 6); y = random.randint(0, h)
            d.line([x, y, x + random.randint(-4, 4), y + random.randint(10, 40)], fill=(10, 9, 8), width=2)
        d.line([x0, 0, x0, h], fill=(8, 8, 8), width=3)
    noisy(img, 5).save(os.path.join(OUT, "yakisugi.png"))

def koshi():
    # 町家的格子窗:縱向細木條,縫隙後是暗色室內
    w = h = 256
    img = Image.new("RGB", (w, h), (18, 13, 11))
    d = ImageDraw.Draw(img)
    for x in range(8, w, 22):
        for xx in range(10):
            v = int(70 - abs(xx - 5) * 5)
            d.line([x + xx, 0, x + xx, h], fill=(v, int(v * 0.62), int(v * 0.42)))
    d.rectangle([0, 0, w, 14], fill=(74, 48, 32)); d.rectangle([0, h - 14, w, h], fill=(74, 48, 32))
    noisy(img, 4).save(os.path.join(OUT, "koshi.png"))

def noren():
    # 暖簾:藍染布、三道開衩、白色圓形家紋
    w, h = 256, 256
    img = noisy(Image.new("RGB", (w, h), (34, 48, 92)), 9)
    d = ImageDraw.Draw(img)
    for x in range(0, w, 3):  # 織紋
        d.line([x, 0, x, h], fill=(30, 42, 84))
    for x in (w // 4, w // 2, 3 * w // 4):
        d.line([x, 0, x, h], fill=(14, 18, 36), width=3)
    cx, cy = w // 2, int(h * 0.42)
    d.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], outline=(236, 232, 220), width=7)
    d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=(236, 232, 220))
    d.rectangle([0, 0, w, 12], fill=(58, 44, 30))
    img.save(os.path.join(OUT, "noren.png"))

def kasuri():
    # 木板牆(白木板橫貼):淺色杉板
    w = h = 512
    img = Image.new("RGB", (w, h), (196, 160, 118))
    d = ImageDraw.Draw(img)
    board = 64
    for b in range(h // board):
        y0 = b * board
        base = random.randint(176, 206)
        d.rectangle([0, y0, w, y0 + board], fill=(base, int(base * 0.8), int(base * 0.58)))
        for _ in range(40):
            x = random.randint(0, w); y = y0 + random.randint(6, board - 6)
            d.line([x, y, x + random.randint(30, 120), y + random.randint(-2, 2)], fill=(base - 26, int((base - 26) * 0.78), int((base - 26) * 0.55)), width=1)
        d.line([0, y0, w, y0], fill=(70, 48, 32), width=3)
    noisy(img, 5).save(os.path.join(OUT, "cedar_board.png"))

def vermilion():
    # 朱漆(鳥居的丹塗り):朱紅底、細直紋、亮暗漸層
    w = h = 256
    img = Image.new("RGB", (w, h), (226, 70, 34))
    d = ImageDraw.Draw(img)
    for x in range(w):
        v = int(14 * math.sin(x / w * math.pi * 6) + random.randint(-4, 4))
        d.line([x, 0, x, h], fill=(max(0, min(255, 226 + v)), max(0, 70 + v // 3), max(0, 34 + v // 3)))
    for _ in range(90):
        x = random.randint(0, w); y = random.randint(0, h)
        d.line([x, y, x + random.randint(-1, 1), y + random.randint(20, 90)], fill=(196, 52, 26), width=1)
    img.filter(ImageFilter.GaussianBlur(0.5)).save(os.path.join(OUT, "vermilion.png"))

def plaque():
    # 額束的神額:黑底金框金字
    from PIL import ImageFont
    w, h = 128, 256
    img = Image.new("RGB", (w, h), (22, 18, 16))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, w - 5, h - 5], outline=(196, 156, 70), width=6)
    d.rectangle([14, 14, w - 15, h - 15], outline=(150, 118, 52), width=2)
    font_path = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "NotoSerifTC.ttf")
    f = ImageFont.truetype(font_path, 84)
    try: f.set_variation_by_axes([800])
    except Exception: pass
    for i, ch in enumerate("山神"):
        d.text((w // 2, 74 + i * 100), ch, font=f, fill=(226, 188, 96), anchor="mm")
    img.save(os.path.join(OUT, "plaque.png"))

if __name__ == "__main__":
    for f in (shoji, kawara, namako, yakisugi, koshi, noren, kasuri, vermilion, plaque):
        f(); print("ok", f.__name__)
