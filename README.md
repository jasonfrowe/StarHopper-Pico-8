# Star Hopper (PICO-8)

A PICO-8 port of Star Hopper, originally written for the Picocomputer 6502
(`/Users/rowe/Software/rp6502/RPDemo`).

## Layout

| Path | What it is |
|---|---|
| `starhopper.p8` | The cart: `#include`s the Lua in `src/`, plus the sprite sheet, sfx and music |
| `src/*.lua` | Game code. Edit these in VS Code |
| `music/*.p8` | One cart per tune, holding its sfx and music patterns. Run one in PICO-8 to hear it |
| `tools/import_gfx.py` | Converts the RP6502 PNGs into the cart's `__gfx__`: matches colors to the PICO-8 palette and halves 16×16 art to 8×8 |
| `tools/vgm2p8.py` | Converts the RP6502 VGM tunes into `music/*.p8` |
| `tools/snap.py` | Runs the cart headless for N frames, prints runtime errors and saves `snap.png` |
| `tools/autopilot.lua` | Invincible auto-play for `snap.py`, logging each wave: `python3 tools/snap.py --frames 20000 --each @tools/autopilot.lua` |
| `tools/bosstest.lua` | Invincible boss-fight autopilot for `snap.py` (set `bl=<level>` first) |
| `tools/tokens.py` | Approximate token count per source file |

## Workflow

1. Open this folder in VS Code. Accept the recommended **pico8-ls** extension, which adds
   completion, PICO-8 API docs on hover, error checking and a token count.
2. Press **Cmd+Shift+B** ("Run in PICO-8") to launch the cart.
3. Edit `src/*.lua` in VS Code, save, then press **Ctrl+R** in the PICO-8 window.
   Included files are re-read each time the cart runs.
4. Draw sprites, sfx and music in PICO-8's own editors (Esc to switch), then **Ctrl+S**.
   Saving keeps the `#include` lines, so your code stays in `src/`.

From the PICO-8 console you can also run `load starhopper/starhopper`, because
`~/Library/Application Support/pico-8/carts/starhopper` is a symlink to this folder.

Keep code lowercase. PICO-8 shows uppercase letters as glyphs.

## Graphics

All art is 8×8, and bosses are 24×16. `tools/import_gfx.py` shrinks the original
16×16 art with a majority vote over each 2×2 block. That makes a usable first
pass; touch up sprites in PICO-8's sprite editor, but re-running the tool
overwrites the cells it owns (see the sheet map at the top of the script).
The map is unused, so sprites 128–255 hold art too.

## Music

The OPL2 tunes share one channel layout, so the conversion is mechanical:

| OPL2 | PICO-8 |
|---|---|
| CH0 lead | P0, square |
| CH1 lead/arp | P1, organ |
| CH2 bass | P2, tilted saw |
| CH3–5 kick, snare, hat | P3, merged; one hit per row, snare > kick > hat |
| CH6 pad | dropped (`--pad` plays it on P1 where the arp rests) |

Each song is split into 32-row sfx, and repeated phrases are stored once.
A song needs 12–48 sfx, while a cart has 64 slots in total, so each tune gets
its own cart in `music/`. `music_play("level_01")` copies that cart's sfx
0–51 and patterns into memory with `reload()` and starts it. Sfx 52–63 are
kept for sound effects.

Waveforms, volumes and drum sounds are set at the top of `tools/vgm2p8.py`.
Re-run `python3 tools/vgm2p8.py all` after changing them.

**Limitation:** PICO-8 only allows loading data from other carts (multi-cart)
locally and in exported binaries or web builds (up to 16 carts). On the BBS
and in Splore, a cart can't read other carts, so a BBS release would need the
music cut down to fit a single cart.

## Port notes

| RP6502 | PICO-8 | Plan |
|---|---|---|
| 320×240, 60 fps | 128×128, `_update60` | Positions and speeds scaled by 0.4. All sprites 8×8 |
| 9k lines of C | 8192-token limit | Hardware code (XRAM, OPL, VGM, gamepad mapper, tile planes) is dropped. Waves, bosses, bonus tally, title, game over and victory: done, ~5600 tokens |
| 176 enemy frames of 16×16 | 256 sprites of 8×8 (no map) | Every frame halved: 195 sprites used |
| BG/FG tile starfields | Procedural `line()` stars | Done |
| 13 OPL2 VGM tracks, generated SFX | 64 sfx, 64 music patterns | Auto-converted, one cart per tune (see Music) |
