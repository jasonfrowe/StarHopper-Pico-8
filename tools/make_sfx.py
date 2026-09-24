#!/usr/bin/env python3
"""Write Star Hopper's sound effects into sfx 52-62 of starhopper.p8.

The RP6502 effects are procedural OPL2 clips (RPDemo/tools/generate_sfx.py):
pitch sweeps, re-struck chime notes and volume tremolos. They are described
again here in the same terms (Hz, milliseconds) and sampled at PICO-8 note
resolution; OPL envelopes become a linear volume ramp. Music owns sfx 0-51
and peaks at volume 5 (see MUSIC_GAIN in vgm2p8.py), so effects start at
6-7 to sit on top of it.

Slots are ordered by the original's priority tiers (fire < pickup/tally/low
energy < enemy destroyed < player hit/die, extra life, fanfares), which
src/sound.lua relies on. It also needs each effect's length: this script
prints the Lua table line to paste there.

Usage:  python3 tools/make_sfx.py
"""
import math
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CART = os.path.join(ROOT, "starhopper.p8")

C5, E5, G5, C6, E6 = 523.25, 659.25, 783.99, 1046.50, 1318.51


def hz(name):
    """Note name like "C5", "D#4" -> Hz."""
    n = "C C# D D# E F F# G G# A A# B".split().index(name[:-1])
    return 440 * 2 ** ((n - 9) / 12 + int(name[-1]) - 4)

# waveforms: 0 tri, 1 tilted saw, 2 saw, 3 square, 4 pulse, 5 organ, 6 noise, 7 phaser
# segments: ("sweep", hz0, hz1, ms, vol0, vol1)  linear pitch and volume glide
#           ("rest", ms)
#           ("trem", hz, tl_curve, step_ms, cycles, vol)  OPL total-level flutter
#           ("arp", "C6 G5 ...", ms_each, vol0, vol1)  stepped notes, volume ramps across them
def chime(notes, on_ms, vol):
    segs = []
    for f in notes:
        segs += [("sweep", f, f, on_ms, vol, vol - 2), ("rest", 20)]
    return segs


# (slot, name, tier, speed, waveform, segments)
SFX = [
    (52, "plyrfire", 1, 1, 0, [("sweep", 900, 350, 70, 6, 3)]),
    (53, "enmyfire", 1, 1, 0, [("sweep", 450, 200, 90, 5, 2)]),
    (54, "tally", 2, 1, 0, [("sweep", 440, 1320, 140, 5, 3)]),
    (55, "pickup", 2, 1, 0, [("sweep", 440, 1320, 140, 7, 5)]),
    (56, "lowenrgy", 2, 2, 1, [("sweep", 660, 660, 90, 6, 6), ("rest", 60), ("sweep", 660, 660, 90, 6, 6)]),
    # the destroyed/hit sounds are tuneful arcade arpeggios rather than the
    # original's noisy FM sweeps
    (57, "enmydie", 3, 1, 4, [("arp", "C6 A5 F5 D5 A4", 25, 7, 4)]),
    (58, "plyrhit", 4, 1, 3, [("arp", "E5 C5 G4", 35, 7, 5)]),
    (59, "plyrdie", 4, 3, 3, [("arp", "C6 G5 D#5 C5 G4 D#4 C4 G3 D#3 C3", 60, 7, 2)]),
    (60, "xtralife", 4, 3, 5, [("trem", 740, (0, 1, 2, 3, 5, 8, 12, 16, 12, 8, 5, 3, 2, 1, 0), 9, 6, 7)]),
    (61, "lvlclear", 4, 3, 5, chime((C5, E5, G5, C6), 140, 7)),
    (62, "victory", 4, 6, 5, chime((C5, E5, G5, C6, G5, C6), 130, 7)
     + [("trem", E6, (0, 2, 5, 9, 14, 9, 5, 2), 10, 8, 7)]),
]


def seg_ms(s):
    return {"sweep": lambda: s[3], "rest": lambda: s[1], "trem": lambda: len(s[2]) * s[3] * s[4],
            "arp": lambda: len(s[1].split()) * s[2]}[s[0]]()


def sample(segs, t_ms):
    """(hz, vol) at time t, or None for silence."""
    for s in segs:
        d = seg_ms(s)
        if t_ms < d:
            k = t_ms / d
            if s[0] == "sweep":
                return s[1] + (s[2] - s[1]) * k, s[4] + (s[5] - s[4]) * k
            if s[0] == "arp":
                return hz(s[1].split()[int(t_ms // s[2])]), s[3] + (s[4] - s[3]) * k
            if s[0] == "trem":
                tl = s[2][int(t_ms // s[3]) % len(s[2])]
                return s[1], s[5] * (1 - tl / 24)
            return None
        t_ms -= d
    return None


def pitch(hz):
    # PICO-8 pitch 0 is C-0 (65.41 Hz); 33 is A-2 (440 Hz)
    return max(0, min(63, round(12 * math.log2(hz / 65.41))))


def build(speed, wave, segs):
    note_ms = speed * 1000 / 120  # one speed unit is ~1/120 s
    total = sum(seg_ms(s) for s in segs)
    n = min(32, math.ceil(total / note_ms))
    notes = []
    for i in range(n):
        hv = sample(segs, (i + 0.5) * note_ms)
        notes.append((pitch(hv[0]), wave, max(1, round(hv[1])), 0) if hv and hv[1] >= 0.5 else (0, 0, 0, 0))
    if total > 32 * note_ms:
        print(f"  warning: {total:.0f}ms is longer than 32 notes at speed {speed}")
    return notes, n * note_ms / 1000


def line(notes, speed):
    notes = notes + [(0, 0, 0, 0)] * (32 - len(notes))
    return "%02x%02x%02x%02x" % (0, speed, 0, 0) + "".join("%02x%x%x%x" % n for n in notes)


def main():
    text = open(CART).read()
    m = re.search(r"^__sfx__\n((?:(?!__\w+__\n).*\n)*)", text, re.M)
    rows = m.group(1).splitlines() if m else []
    rows += [line([], 16)] * (64 - len(rows))
    tiers, lens = [], []
    for slot, name, tier, speed, wave, segs in SFX:
        notes, secs = build(speed, wave, segs)
        rows[slot] = line(notes, speed)
        tiers.append(tier)
        lens.append(round(secs, 2))
        print(f"sfx {slot} {name:9s} {len(notes):2d} notes, {secs:.2f}s")
    body = "__sfx__\n" + "\n".join(rows) + "\n"
    text = text[:m.start()] + body + text[m.end():] if m else text.rstrip("\n") + "\n" + body
    with open(CART, "w") as f:
        f.write(text)
    print("\nfor src/sound.lua:")
    print('sfx_tier=split"%s"' % ",".join(map(str, tiers)))
    print('sfx_len=split"%s"' % ",".join("%g" % l for l in lens))


if __name__ == "__main__":
    main()
