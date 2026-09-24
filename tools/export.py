#!/usr/bin/env python3
"""Export the game as a web build (build/starhopper_html/) and optionally push it to itch.io.

The music carts are bundled in. Exports store bundled carts by bare name
("level_01.p8", not "music/level_01.p8"), so the export runs from a staging
copy with music/*.p8 beside the cart and src/music.lua's mdir set to "".

The cart needs a __label__ first:
        .venv/bin/python tools/snap.py --frames 200 --each "hiscore=0" --label

Usage:  python3 tools/export.py                          # build only
        python3 tools/export.py --push jfrowe/GAME:html  # build, then butler push
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
BUILD = os.path.join(ROOT, "build")
STAGE = os.path.join(BUILD, "stage")
OUT = os.path.join(BUILD, "starhopper_html")

sys.path.insert(0, HERE)
from find_pico8 import find_pico8  # noqa: E402

BUTLER_PATHS = [
    "~/Software/Pico8/butler-darwin-arm64/butler",
    "~/Library/Application Support/itch/apps/butler/butler",
]


def find_butler():
    env = os.environ.get("BUTLER")
    if env:
        return os.path.expanduser(env)
    for p in BUTLER_PATHS:
        p = os.path.expanduser(p)
        if os.path.isfile(p):
            return p
    return shutil.which("butler") or sys.exit("can't find butler: set BUTLER=/path/to/butler")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--push", metavar="USER/GAME:CHANNEL", help="butler push target, e.g. jfrowe/star-hopper-pico-8:html")
    args = ap.parse_args()

    with open(os.path.join(ROOT, "starhopper.p8")) as f:
        if "\n__label__\n" not in f.read():
            sys.exit("starhopper.p8 has no label: run snap.py --label first (see this file's docstring)")

    shutil.rmtree(BUILD, ignore_errors=True)
    shutil.copytree(os.path.join(ROOT, "src"), os.path.join(STAGE, "src"))
    shutil.copy(os.path.join(ROOT, "starhopper.p8"), STAGE)
    music = []
    for p in sorted(glob.glob(os.path.join(ROOT, "music", "*.p8"))):
        shutil.copy(p, STAGE)
        music.append(os.path.basename(p))
    mfile = os.path.join(STAGE, "src", "music.lua")
    with open(mfile) as f:
        text = f.read()
    if 'mdir="music/"' not in text:
        sys.exit('src/music.lua no longer sets mdir="music/"; update export.py')
    with open(mfile, "w") as f:
        f.write(text.replace('mdir="music/"', 'mdir=""'))

    r = subprocess.run([find_pico8(), "starhopper.p8", "-export", " ".join(["-f starhopper.html"] + music)],
                       cwd=STAGE, capture_output=True, text=True, timeout=120)
    html = os.path.join(STAGE, "starhopper_html")
    if not os.path.isfile(os.path.join(html, "index.html")):
        sys.exit("export failed:\n" + r.stdout + r.stderr)
    shutil.move(html, OUT)
    shutil.rmtree(STAGE)
    print(f"exported {len(music) + 1} carts to {os.path.relpath(OUT, ROOT)}/")

    if args.push:
        subprocess.run([find_butler(), "push", OUT, args.push], check=True)


if __name__ == "__main__":
    main()
