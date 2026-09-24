"""Locate the PICO-8 binary: $PICO8, the usual install spots, pico8 on $PATH, then Spotlight."""
import os
import shutil
import subprocess
import sys

# where to look when $PICO8 isn't set (first match wins)
PICO8_PATHS = [
    "~/Software/Pico8/PICO-8.app/Contents/MacOS/pico8",
    "~/Software/pico-8/PICO-8.app/Contents/MacOS/pico8",
    "/Applications/PICO-8.app/Contents/MacOS/pico8",
    "~/Applications/PICO-8.app/Contents/MacOS/pico8",
    "~/pico-8/pico8",
]


def find_pico8():
    env = os.environ.get("PICO8")
    if env:
        return os.path.expanduser(env)
    for p in PICO8_PATHS:
        p = os.path.expanduser(p)
        if os.path.isfile(p):
            return p
    p = shutil.which("pico8")
    if p:
        return p
    if sys.platform == "darwin":
        r = subprocess.run(["mdfind", "kMDItemFSName == 'PICO-8.app'"], capture_output=True, text=True)
        for app in r.stdout.split("\n"):
            p = os.path.join(app, "Contents/MacOS/pico8")
            if app and os.path.isfile(p):
                return p
    sys.exit("can't find PICO-8: set PICO8=/path/to/pico8 (the binary, inside the .app on macOS)")
