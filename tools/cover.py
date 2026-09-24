#!/usr/bin/env python3
"""Compose the itch.io cover (630x500, itch's recommended size) from the cart's art.

The scene is laid out on a 126x100 PICO-8-pixel canvas and scaled 5x:
the title logo over a boss fight. Writes itch/cover.png.

Usage:  .venv/bin/python tools/cover.py [--seed 3]
"""
import argparse
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from import_gfx import PICO8, boss_slot  # noqa: E402

W, H, SCALE = 126, 100, 5
LOGO_BLUE = (0x06, 0x5A, 0xB5)  # secret colour 140, which the title swaps in for colour 1
STAR_COLS = [1, 5, 12, 11, 10, 6, 8, 7]


def sections():
    with open(os.path.join(ROOT, "starhopper.p8")) as f:
        text = f.read()
    out = {}
    for part in text.split("\n__")[1:]:
        name, _, body = part.partition("__\n")
        out[name] = body.split()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=3, help="starfield layout")
    args = ap.parse_args()
    sec = sections()
    sheet = [[int(c, 16) for c in row] for row in sec["gfx"]]
    # the logo lives in the map as sheet-format rows (64 bytes, low nibble first)
    mem = bytes.fromhex("".join(sec["map"]))
    logo = [[(mem[y * 64 + x // 2] >> (x % 2 * 4)) & 15 for x in range(128)] for y in range(40)]

    im = Image.new("RGB", (W, H), PICO8[0])
    px = im.load()

    def put(x, y, c, colmap=None):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = (colmap or {}).get(c) or PICO8[c]

    def spr(n, x, y, w=1, h=1, colmap=None):
        sx, sy = n % 16 * 8, n // 16 * 8
        for j in range(h * 8):
            for i in range(w * 8):
                c = sheet[sy + j][sx + i]
                if c:
                    put(x + i, y + j, c, colmap)

    rnd = random.Random(args.seed)
    for _ in range(40):
        x, y, n = rnd.randrange(W), rnd.randrange(H), rnd.choice([0, 0, 3])
        c = rnd.choice(STAR_COLS)
        for k in range(n + 1):
            put(x, y + k, c)

    # boss 5 with its weak spot lit (yellow = vulnerable), bullets from both guns
    bx, by = 51, 47
    spr(boss_slot(4, 0), bx, by, 3, 2, {15: PICO8[10]})
    for y in (64, 78):
        spr(9, bx, y)
        spr(10, bx + 16, y)
    # enemies around it: a zig-zag chain, attack posts, a dying one
    for i, (x, y) in enumerate([(8, 44), (14, 52), (20, 60), (14, 68)]):
        spr(22 + i % 3, x, y)
    spr(22 + 3 * 6, 98, 50)
    spr(22 + 3 * 6 + 1, 110, 58)
    spr(22 + 2 * 6 + 4, 90, 66)
    spr(2, 100, 64)
    spr(2, 104, 72)
    spr(2, 24, 76)
    spr(4, 104, 86)  # S pickup
    # the ship and its shots, lined up on the boss
    spr(16, 59, 88)
    for y in (78, 70):
        spr(1, 59, y)

    for y in range(39):
        for x in range(100):
            c = logo[y][x]
            if c:
                put(13 + x, 4 + y, c, {1: LOGO_BLUE})

    out = os.path.join(ROOT, "itch", "cover.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.resize((W * SCALE, H * SCALE), Image.NEAREST).save(out)
    print(f"saved {os.path.relpath(out, ROOT)}")


if __name__ == "__main__":
    main()
