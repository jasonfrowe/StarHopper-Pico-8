#!/usr/bin/env python3
"""Import Star Hopper PNG art from the RP6502 project into starhopper.p8's __gfx__.

Each source frame is mapped to the nearest PICO-8 colour, 16x16 art is halved
to 8x8, and the result is pasted into the sprite sheet at the slot given by
layout(). Only those cells are touched, so sprites you draw in the PICO-8
editor elsewhere on the sheet are kept -- but re-running the tool overwrites
any hand touch-ups inside them.

Usage:  .venv/bin/python tools/import_gfx.py [--src /path/to/RPDemo] [--preview out.png]
"""
import argparse
import os
import re
import sys
from collections import Counter

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CART = os.path.join(HERE, "..", "starhopper.p8")
DEFAULT_SRC = "/Users/jasonrowe/Software/rp6502/RPDemo"

# The 16 standard PICO-8 colours.
PICO8 = [
    (0x00, 0x00, 0x00), (0x1D, 0x2B, 0x53), (0x7E, 0x25, 0x53), (0x00, 0x87, 0x51),
    (0xAB, 0x52, 0x36), (0x5F, 0x57, 0x4F), (0xC2, 0xC3, 0xC7), (0xFF, 0xF1, 0xE8),
    (0xFF, 0x00, 0x4D), (0xFF, 0xA3, 0x00), (0xFF, 0xEC, 0x27), (0x00, 0xE4, 0x36),
    (0x29, 0xAD, 0xFF), (0x83, 0x76, 0x9C), (0xFF, 0x77, 0xA8), (0xFF, 0xCC, 0xAA),
]

# Explicit overrides for source colours where the nearest match looks wrong.
# Key: (r, g, b) of the source pixel, value: PICO-8 colour index.
OVERRIDES = {
    (0x00, 0x00, 0xAA): 1,   # logo fill (drawn as the brighter secret colour 140 on the title)
    (0x55, 0x55, 0xFF): 12,  # CGA blue (player hull, S pickup)
    (0xFF, 0x55, 0x55): 8,   # CGA light red (player engine)
    (0xFF, 0x1D, 0x1D): 8,   # red (explosion ring)
    (0xD0, 0x6A, 0x03): 9,   # asteroid orange
    (0x29, 0x65, 0x2B): 3,   # enemy dark green
    (0x3F, 0xB1, 0x34): 11,  # enemy green
    (0x49, 0x49, 0xA4): 13,  # enemy blue-grey
    (0x54, 0x60, 0xA4): 12,  # enemy blue
    (0x7D, 0x43, 0xAC): 2,   # enemy purple
    (0x80, 0x6D, 0x31): 4,   # enemy olive
    (0x96, 0xA6, 0xA9): 6,   # enemy light grey
    (0xA1, 0x2B, 0x2E): 2,   # enemy dark red
    (0xE8, 0x46, 0x22): 8,   # enemy red/orange cores
    (0xD5, 0xAD, 0x09): 10,  # gold (GAME OVER letters)
    (0x6B, 0x70, 0x6C): 15,  # boss weak spot grey: its own colour so the game can recolour it
                             # with pal(15,..); drawn grey (5) by default
}

# Sprite sheet map (sprite n = column n%16, row n//16). The starfield is drawn
# procedurally, so the map is unused and sprites 128-255 are free for art.
#   1-13     projectiles, pickups (E S P), asteroids, explosion rings
#   16-21    player: idle, right, left, explode x3
#   22-63    enemies: 7 types x (3 flying + 3 dying) frames
#   64-71    GAME OVER letters
#   96-255   bosses: 7 levels x 3 frame sets (A, B, attack), each a 3x2 block
PLAYER, ENEMY, LETTERS = 16, 22, 64


def boss_slot(level, frame_set):
    """First sprite of a boss frame: five 3x2 blocks per two sheet rows, from row 6."""
    n = level * 3 + frame_set
    return 96 + (n // 5) * 32 + (n % 5) * 3


# Cells redrawn by hand for the smaller screen, written after the imported
# art ('.' = transparent, hex digits = PICO-8 colours).
HAND = {
    2: [  # enemy bullet: the original 5x5 cross is too big at 128px
        "........",
        "........",
        "........",
        "...8....",
        "..8e8...",
        "...8....",
        "........",
        "........",
    ],
}


def layout(src):
    """Yield (first sprite, PIL image at source resolution, downscale factor)."""
    proj = Image.open(os.path.join(src, "Sprites/Projectiles.png")).convert("RGBA")
    player = Image.open(os.path.join(src, "Sprites/Player.png")).convert("RGBA")
    enemies = Image.open(os.path.join(src, "Sprites/Enemies.png")).convert("RGBA")
    cell = lambda im, i, w: im.crop((i * w, 0, i * w + w, im.height))
    for i in range(13):
        yield 1 + i, cell(proj, i, 8), 1
    for i in range(6):
        yield PLAYER + i, cell(player, i, 16), 2
    for i in range(42):
        yield ENEMY + i, cell(enemies, i, 16), 2
    for i in range(8):
        yield LETTERS + i, cell(enemies, 42 + i, 16), 2
    # bosses are 3x2 grids of 16x16 source frames: 50 + 18*level + 6*set
    for level in range(7):
        for fs in range(3):
            boss = Image.new("RGBA", (48, 32))
            for k in range(6):
                boss.paste(cell(enemies, 50 + level * 18 + fs * 6 + k, 16), ((k % 3) * 16, (k // 3) * 16))
            yield boss_slot(level, fs), boss, 2


def reduce(im, factor):
    """Map to PICO-8 colours (None = transparent), shrinking by 2 with a
    majority vote over each 2x2 block (transparent unless 2+ pixels are opaque)."""
    px = [[None if im.getpixel((x, y))[3] < 128 else nearest(im.getpixel((x, y))[:3])
           for x in range(im.width)] for y in range(im.height)]
    if factor == 1:
        return px
    out = []
    for y in range(0, im.height, 2):
        row = []
        for x in range(0, im.width, 2):
            block = [c for c in (px[y][x], px[y][x + 1], px[y + 1][x], px[y + 1][x + 1]) if c is not None]
            row.append(Counter(block).most_common(1)[0][0] if len(block) >= 2 else None)
        out.append(row)
    return out


def nearest(rgb):
    if rgb in OVERRIDES:
        return OVERRIDES[rgb]
    r, g, b = rgb
    return min(range(16), key=lambda i: (PICO8[i][0] - r) ** 2 * 3
               + (PICO8[i][1] - g) ** 2 * 4 + (PICO8[i][2] - b) ** 2 * 2)


def logo(src):
    """The STAR HOPPER logo: rendered from the HUD tile map (tile rows 4-16,
    columns 8-32), cropped, and halved like the sprites."""
    tiles = Image.open(os.path.join(src, "Sprites/StarFields_tiles.png"))
    hud = open(os.path.join(src, "images/StarFields_HUD_map.bin"), "rb").read()
    im = Image.new("RGBA", (200, 104))
    for ty in range(4, 17):
        for tx in range(8, 33):
            idx = tiles.crop((hud[ty * 40 + tx] * 8, 0, hud[ty * 40 + tx] * 8 + 8, 8))
            t = idx.convert("RGBA")
            # palette index 0 is transparent
            t.putalpha(Image.frombytes("L", idx.size, bytes(0 if v == 0 else 255 for v in idx.getdata())))
            im.paste(t, ((tx - 8) * 8, (ty - 4) * 8))
    x0, y0, x1, y1 = im.getbbox()
    return im.crop((x0, y0, x0 + (x1 - x0 + 1) // 2 * 2, y0 + (y1 - y0 + 1) // 2 * 2))


LOGO_ROWS = 40  # the logo is stored at map memory 0x2000 with a 64-byte row stride


def write_logo(text, px):
    """Store logo pixels in the (unused) upper map, in sprite-sheet layout, so
    one memcpy(0x1000,0x2000,..) drops it onto sheet rows 64+ for sspr()."""
    if len(px) > LOGO_ROWS or len(px[0]) > 128:
        sys.exit("logo too big")
    data = bytearray(4096)
    for y, row in enumerate(px):
        for x, c in enumerate(row):
            data[y * 64 + x // 2] |= (c or 0) << (4 * (x % 2))
    body = "".join(data[i:i + 128].hex() + "\n" for i in range(0, 4096, 128))
    m = re.search(r"^__map__\n(?:(?!__\w+__\n).*\n)*", text, re.M)
    if m:
        return text[:m.start()] + "__map__\n" + body + text[m.end():]
    return text.rstrip("\n") + "\n__map__\n" + body


def read_gfx(lines):
    start = lines.index("__gfx__\n") + 1
    end = start
    while end < len(lines) and not re.match(r"^__\w+__$", lines[end].strip()):
        end += 1
    rows = [list(l.strip().ljust(128, "0")) for l in lines[start:end]]
    rows += [["0"] * 128 for _ in range(128 - len(rows))]
    return start, end, rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--preview", help="also write an 8x preview PNG of the sheet")
    args = ap.parse_args()

    with open(CART) as f:
        lines = f.readlines()
    start, end, sheet = read_gfx(lines)

    for spr, im, factor in layout(args.src):
        px = reduce(im, factor)
        ox, oy = (spr % 16) * 8, (spr // 16) * 8
        if ox + len(px[0]) > 128 or oy + len(px) > 128:
            sys.exit(f"art for sprite {spr} does not fit on the sheet")
        for y, row in enumerate(px):
            for x, c in enumerate(row):
                sheet[oy + y][ox + x] = "%x" % (c or 0)
    for spr, rows in HAND.items():
        ox, oy = (spr % 16) * 8, (spr // 16) * 8
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                sheet[oy + y][ox + x] = "0" if ch == "." else ch

    lines[start:end] = ["".join(r) + "\n" for r in sheet]
    lg = reduce(logo(args.src), 2)
    text = write_logo("".join(lines), lg)  # build everything before touching the cart
    with open(CART, "w") as f:
        f.write(text)
    print(f"updated __gfx__ and the {len(lg[0])}x{len(lg)} logo in __map__ of {os.path.normpath(CART)}")

    if args.preview:
        lp = Image.new("RGB", (len(lg[0]), len(lg)))
        for y, row in enumerate(lg):
            for x, c in enumerate(row):
                lp.putpixel((x, y), PICO8[c or 0])
        lp.resize((lp.width * 6, lp.height * 6), Image.NEAREST).save(args.preview.replace(".png", "_logo.png"))
        out = Image.new("RGB", (128, 128))
        for y in range(128):
            for x in range(128):
                out.putpixel((x, y), PICO8[int(sheet[y][x], 16)])
        out.resize((1024, 1024), Image.NEAREST).save(args.preview)
        print(f"preview written to {args.preview}")


if __name__ == "__main__":
    main()
