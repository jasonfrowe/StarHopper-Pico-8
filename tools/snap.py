#!/usr/bin/env python3
"""Run starhopper.p8 headless for N frames and save the screen as a PNG.

Catches runtime errors without opening the PICO-8 window, and lets you (or
Claude) see a frame. Optional Lua runs before each update to fake input.

Usage:  python3 tools/snap.py [--frames 120] [--out snap.png] [--each "lua code"]
"""
import argparse
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
CART = os.path.join(ROOT, "starhopper.p8")
PICO8 = "/Users/rowe/Software/pico-8/PICO-8.app/Contents/MacOS/pico8"
CARTS_DIR = os.path.expanduser("~/Library/Application Support/pico-8/carts")
DUMP = "starhopper_snap.txt"

sys.path.insert(0, HERE)
from import_gfx import PICO8 as PALETTE  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=120)
    ap.add_argument("--out", default=os.path.join(ROOT, "snap.png"))
    ap.add_argument("--each", default="", help="Lua run before each _update60 (i = frame number)")
    ap.add_argument("--scale", type=int, default=4)
    args = ap.parse_args()

    with open(CART) as f:
        text = f.read()
    head, rest = text.split("__lua__\n", 1)
    lua_end = rest.find("\n__gfx__")
    lua, data = (rest, "") if lua_end < 0 else (rest[:lua_end], rest[lua_end + 1:])

    harness = f"""
_init()
for i=1,{args.frames} do
 {args.each}
 if _update60 then _update60() else _update() end
end
_draw()
local s=""
for a=0x6000,0x7fff do s..=sub(tostr(@a,true),5,6) end
printh(s,"{DUMP}",true)
-- without callbacks, -x exits instead of entering the main loop
_update60,_update,_draw=nil
"""
    tmp = os.path.join(ROOT, "snap_tmp.p8")
    with open(tmp, "w") as f:
        f.write(head + "__lua__\n" + lua + "\n" + harness + "\n" + data)

    dump = os.path.join(CARTS_DIR, DUMP)
    if os.path.exists(dump):
        os.remove(dump)
    try:
        r = subprocess.run([PICO8, "-x", "snap_tmp.p8"], cwd=ROOT, capture_output=True, text=True, timeout=30)
    finally:
        os.remove(tmp)
    out = (r.stdout + r.stderr).replace("RUNNING: snap_tmp.p8\n", "")
    if out.strip():
        print(out.strip())
    if not os.path.exists(dump):
        sys.exit("no screen dump produced (runtime error?)")

    with open(dump) as f:
        b = bytes.fromhex(f.read().strip())
    os.remove(dump)
    im = Image.new("RGB", (128, 128))
    for i, v in enumerate(b):
        y, x = divmod(i * 2, 128)
        im.putpixel((x, y), PALETTE[v & 15])
        im.putpixel((x + 1, y), PALETTE[v >> 4])
    im.resize((128 * args.scale, 128 * args.scale), Image.NEAREST).save(args.out)
    print(f"saved {args.out}")


if __name__ == "__main__":
    main()
