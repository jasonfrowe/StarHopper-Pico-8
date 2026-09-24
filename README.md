# Star Hopper (PICO-8)

A PICO-8 port of Star Hopper, originally written for the Picocomputer 6502
(`/Users/rowe/Software/rp6502/RPDemo`).

## Layout

| Path | What it is |
|---|---|
| `starhopper.p8` | The cart: `#include`s the Lua in `src/`, plus the sprite sheet, sfx and music |
| `src/*.lua` | Game code. Edit these in VS Code |
| `tools/import_gfx.py` | Converts the RP6502 PNGs into the cart's `__gfx__`, matching colors to the PICO-8 palette |
| `tools/snap.py` | Runs the cart headless for N frames, prints runtime errors and saves `snap.png` |

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

## Port notes

| RP6502 | PICO-8 | Plan |
|---|---|---|
| 320×240, 60 fps | 128×128, `_update60` | Scale positions and speeds by about 0.4. Keep 16×16 player and enemy sprites, or shrink to 8×8 |
| 9k lines of C | 8192-token limit | Hardware code (XRAM, OPL, VGM, gamepad mapper, tile planes) is dropped. Enemy and boss logic becomes table-driven |
| 176 enemy frames of 16×16 | 128 sprites of 8×8, or 256 without map | Fewer animation frames, recolor with `pal()`, redraw bosses smaller |
| BG/FG tile starfields | Procedural `line()` stars | Done |
| 13 OPL2 VGM tracks, generated SFX | 64 sfx, 64 music patterns | Rewrite about 4 tunes by hand in the PICO-8 tracker |
