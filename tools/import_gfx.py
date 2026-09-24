#!/usr/bin/env python3
"""Import Star Hopper PNG art from the RP6502 project into starhopper.p8's __gfx__.

Each source frame is mapped to the nearest PICO-8 colour and pasted into the
sprite sheet at the slot given in LAYOUT. Only the cells listed in LAYOUT are
touched, so sprites you draw in the PICO-8 editor elsewhere on the sheet are
kept. Re-running the tool overwrites the listed cells, though.

Usage:  python3 tools/import_gfx.py [--src /path/to/RPDemo] [--preview out.png]
"""
import argparse
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CART = os.path.join(HERE, "..", "starhopper.p8")
DEFAULT_SRC = "/Users/rowe/Software/rp6502/RPDemo"

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
    (0xD5, 0xAD, 0x09): 10,  # gold (weak spots, GAME OVER letters)
}

# (png relative to --src, frame width, frame height, source frame indices, first sprite number)
# Frames are read left-to-right from a horizontal strip and written left-to-right
# into the sheet starting at the given sprite number (sprite n = column n%16, row n//16).
LAYOUT = [
    ("Sprites/Projectiles.png", 8, 8, range(13), 1),       # sprites 1..13
    ("Sprites/Player.png", 16, 16, range(6), 32),          # sprites 32,34,..,42 (2x2 each)
]


def nearest(rgb):
    if rgb in OVERRIDES:
        return OVERRIDES[rgb]
    r, g, b = rgb
    return min(range(16), key=lambda i: (PICO8[i][0] - r) ** 2 * 3
               + (PICO8[i][1] - g) ** 2 * 4 + (PICO8[i][2] - b) ** 2 * 2)


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

    for png, fw, fh, frames, first in LAYOUT:
        im = Image.open(os.path.join(args.src, png)).convert("RGBA")
        cells_w = fw // 8
        for n, frame in enumerate(frames):
            spr = first + n * cells_w
            ox, oy = (spr % 16) * 8, (spr // 16) * 8
            if ox + fw > 128 or oy + fh > 128:
                sys.exit(f"{png} frame {frame} does not fit at sprite {spr}")
            for y in range(fh):
                for x in range(fw):
                    r, g, b, a = im.getpixel((frame * fw + x, y))
                    c = 0 if a < 128 else nearest((r, g, b))
                    sheet[oy + y][ox + x] = "%x" % c

    lines[start:end] = ["".join(r) + "\n" for r in sheet]
    with open(CART, "w") as f:
        f.writelines(lines)
    print(f"updated __gfx__ in {os.path.normpath(CART)}")

    if args.preview:
        out = Image.new("RGB", (128, 128))
        for y in range(128):
            for x in range(128):
                out.putpixel((x, y), PICO8[int(sheet[y][x], 16)])
        out.resize((1024, 1024), Image.NEAREST).save(args.preview)
        print(f"preview written to {args.preview}")


if __name__ == "__main__":
    main()
