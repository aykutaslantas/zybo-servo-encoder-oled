"""Bir TrueType yazi tipinden 8x16 piksellik karakter bitmapleri uretir (Pillow)."""
from PIL import Image, ImageDraw, ImageFont

CHARS = " 0123456789ACDEIKLMNPTsu<>"


def render(path, size, yoff):
    f = ImageFont.truetype(path, size)
    out = {}
    for ch in CHARS:
        im = Image.new("L", (8, 16), 0)
        d = ImageDraw.Draw(im)
        bb = d.textbbox((0, 0), "0", font=f)          # hizalama icin referans: '0'
        w = bb[2] - bb[0]
        x = (8 - w) // 2 - bb[0]
        d.text((x, yoff), ch, font=f, fill=255)
        out[ch] = [[1 if im.getpixel((c, r)) > 110 else 0 for c in range(8)] for r in range(16)]
    return out
