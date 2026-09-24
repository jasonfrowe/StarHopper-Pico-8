#!/usr/bin/env python3
"""Convert Star Hopper's OPL2 VGM tunes into PICO-8 sfx + music patterns.

Every tune uses the same OPL2 channel layout:
  CH0 lead, CH1 lead/arp, CH2 bass, CH3 kick, CH4 snare, CH5 hi-hat, CH6 pad
PICO-8 has four channels, so they are mapped to:
  P0 = CH0 lead, P1 = CH1 arp, P2 = CH2 bass,
  P3 = drums (CH3-5 merged, one hit per row: snare > kick > hat)
The pad (CH6) is dropped unless --pad is given, in which case it plays on P1
in rows where the arp is silent.

Songs are cut into 32-row PICO-8 sfx. Identical sfx are stored once, so a
song costs one sfx per *unique* 32-row phrase per channel. Music sfx start at
slot 0; slots from --sfx-limit up are left for game sound effects.

Usage:
  python3 tools/vgm2p8.py Level_01                # writes music/level_01.p8
  python3 tools/vgm2p8.py Title --into starhopper.p8
  python3 tools/vgm2p8.py all                     # every tune -> music/*.p8
"""
import argparse
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from vgm_opl import read_vgm  # noqa: E402

SRC_DIR = "/Users/rowe/Software/rp6502/RPDemo/music"
ROWS = 32
SAMPLES_PER_TICK = 735  # 44100 / 60

# PICO-8 waveforms: 0 tri, 1 tilted saw, 2 saw, 3 square, 4 pulse, 5 organ, 6 noise, 7 phaser
# (waveform, max volume) for each melodic PICO-8 channel
VOICES = {0: (3, 5), 1: (5, 4), 2: (1, 6)}
PAD_VOICE = (0, 3)
# drum hit -> (pitch, waveform, volume, effect); effects: 3 drop, 5 fade out.
# Hat and snare are both noise: higher pitch sounds brighter and louder, so the
# hat sits lower than you'd expect (its volume is already the minimum, 1) and
# the snare is at full volume to cut through.
DRUMS = {
    "kick": (18, 0, 7, 3),
    "snare": (36, 6, 7, 5),
    "hat": (46, 6, 1, 5),
}
DRUM_CH = {3: "kick", 4: "snare", 5: "hat"}
DRUM_PRIORITY = {"snare": 3, "kick": 2, "hat": 1}
EMPTY = (0, 0, 0, 0)


def row_length(events):
    """Samples per row: the smallest gap between note-on times."""
    ts = sorted({t for t, kind, _, _ in events if kind == "on"})
    return min(b - a for a, b in zip(ts, ts[1:]))


def melodic_rows(events, ch, row, nrows):
    """Per-row (pitch, volume 0..1, is_attack) or None for one OPL channel."""
    out = [None] * nrows
    start = None
    for t, kind, c, val in events + [(nrows * row, "off", ch, None)]:
        if c != ch:
            continue
        r = round(t / row)
        if start is not None:
            r0, pitch, vol = start
            for i in range(r0, min(max(r, r0 + 1), nrows)):
                out[i] = (pitch, vol, i == r0)
            start = None
        if kind == "on" and r < nrows:
            start = (r, val[0], val[1])
    return out


def to_pico_notes(rows, voice):
    wave, vmax = voice
    notes = []
    for i, cell in enumerate(rows):
        if cell is None:
            notes.append(EMPTY)
            continue
        midi, vol, _ = cell
        pitch = max(0, min(63, midi - 36))
        v = max(1, round(vol * vmax))
        # PICO-8 glides into a repeated identical note without re-attacking,
        # so fade the row before a same-pitch attack to separate them.
        nxt = rows[i + 1] if i + 1 < len(rows) else None
        fx = 5 if nxt and nxt[2] and nxt[0] == midi else 0
        notes.append((pitch, wave, v, fx))
    return notes


def drum_notes(events, row, nrows):
    hits = [None] * nrows
    for t, kind, ch, _ in events:
        if kind != "on" or ch not in DRUM_CH:
            continue
        r = round(t / row)
        if r < nrows:
            name = DRUM_CH[ch]
            if hits[r] is None or DRUM_PRIORITY[name] > DRUM_PRIORITY[hits[r]]:
                hits[r] = name
    return [DRUMS[h] if h else EMPTY for h in hits]


def convert(path, pad=False):
    events, total, _ = read_vgm(path)
    row = row_length(events)
    ticks = round(row / SAMPLES_PER_TICK)
    nrows = -(-round(total / row) // ROWS) * ROWS

    chans = {c: to_pico_notes(melodic_rows(events, c, row, nrows), VOICES[c]) for c in (0, 1, 2)}
    if pad:
        padn = to_pico_notes(melodic_rows(events, 6, row, nrows), PAD_VOICE)
        chans[1] = [a if a != EMPTY else p for a, p in zip(chans[1], padn)]
    chans[3] = drum_notes(events, row, nrows)

    sfx, index, patterns = [], {}, []
    for start in range(0, nrows, ROWS):
        pat = []
        silent = all(n == EMPTY for c in range(4) for n in chans[c][start:start + ROWS])
        for c in range(4):
            chunk = tuple(chans[c][start:start + ROWS])
            # a pattern with every channel off has no length, so a rest
            # pattern keeps one empty sfx on P0 to hold its 32 rows
            if all(n == EMPTY for n in chunk) and not (silent and c == 0):
                pat.append(None)
                continue
            if chunk not in index:
                index[chunk] = len(sfx)
                sfx.append(chunk)
            pat.append(index[chunk])
        patterns.append(pat)
    # 1 PICO-8 speed unit = 183/22050 s, almost exactly 1/120 s, so 2 per 60 Hz tick
    return {"sfx": sfx, "patterns": patterns, "speed": ticks * 2}


def sfx_line(notes, speed):
    head = "%02x%02x%02x%02x" % (0, speed, 0, 0)
    return head + "".join("%02x%x%x%x" % n for n in notes)


def music_line(i, pat, n):
    flags = (1 if i == 0 else 0) | (2 if i == n - 1 else 0)
    return "%02x %s" % (flags, "".join("%02x" % (0x41 + c if s is None else s) for c, s in enumerate(pat)))


def replace_section(text, name, lines, keep_from=0):
    """Replace the first len(lines) rows of a __name__ section (creating it if missing)."""
    m = re.search(r"^__%s__\n((?:(?!__\w+__\n).*\n)*)" % name, text, re.M)
    old = m.group(1).splitlines() if m else []
    blank = sfx_line([EMPTY] * ROWS, 16) if name == "sfx" else "00 41424344"
    new = lines + old[len(lines):] if keep_from else lines
    new += [blank] * (keep_from - len(new)) if keep_from > len(new) else []
    body = "__%s__\n%s\n" % (name, "\n".join(new))
    if m:
        return text[:m.start()] + body + text[m.end():]
    return text.rstrip("\n") + "\n" + body


def write_cart(song, path, sfx_limit):
    n_sfx, n_pat = len(song["sfx"]), len(song["patterns"])
    if n_sfx > sfx_limit or n_pat > 64:
        sys.exit(f"{path}: needs {n_sfx} sfx / {n_pat} patterns (limit {sfx_limit} / 64)")
    sfx = [sfx_line(s, song["speed"]) for s in song["sfx"]]
    music = [music_line(i, p, n_pat) for i, p in enumerate(song["patterns"])]
    if os.path.exists(path):
        text = open(path).read()
        # keep game sfx above the music area
        text = replace_section(text, "sfx", sfx, keep_from=64)
        text = replace_section(text, "music", music)
    else:
        # standalone music carts play themselves, for auditioning in PICO-8
        name = os.path.splitext(os.path.basename(path))[0]
        text = ("pico-8 cartridge // http://www.pico-8.com\nversion 42\n__lua__\n"
                "music(0)\nfunction _draw() cls() print(\"%s\\npattern \"..stat(54),8,8,7) end\n" % name)
        text = replace_section(text, "sfx", sfx)
        text = replace_section(text, "music", music)
    with open(path, "w") as f:
        f.write(text)
    print(f"{os.path.relpath(path, ROOT)}: {n_sfx} sfx, {n_pat} patterns, speed {song['speed']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tune", help="VGM name without extension (e.g. Level_01), or 'all'")
    ap.add_argument("--into", help="write into this cart instead of music/<tune>.p8 (keeps its code, gfx, game sfx)")
    ap.add_argument("--pad", action="store_true", help="play the pad on P1 where the arp is silent")
    ap.add_argument("--sfx-limit", type=int, default=52, help="music may use sfx 0..limit-1 (default 52)")
    ap.add_argument("--src", default=SRC_DIR)
    args = ap.parse_args()

    names = ([os.path.splitext(os.path.basename(p))[0] for p in sorted(glob.glob(os.path.join(args.src, "*.vgm")))]
             if args.tune == "all" else [args.tune])
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    for name in names:
        song = convert(os.path.join(args.src, name + ".vgm"), pad=args.pad)
        out = os.path.join(ROOT, args.into) if args.into else os.path.join(ROOT, "music", name.lower() + ".p8")
        write_cart(song, out, args.sfx_limit)


if __name__ == "__main__":
    main()
