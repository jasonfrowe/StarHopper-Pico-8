# Star Hopper PICO-8 port

- Source game (C, llvm-mos, RP6502): `/Users/rowe/Software/rp6502/RPDemo` (`src/`, `Sprites/`). Behavior reference for the port.
- Code lives in `src/*.lua`, pulled into `starhopper.p8` via `#include` (not recursive; add new files to the cart's `__lua__` list).
- Style: lowercase only, one-space indents, PICO-8 shorthand (`if (c) x`, `+=`), globals are fine. Watch the 8192-token budget.
- Verify changes with `python3 tools/snap.py --frames N [--each "lua"]` and view the PNG it saves; `--each` can fake input or state.
- `tools/import_gfx.py` owns only the sprite cells in its `LAYOUT`; other cells may be hand-drawn in PICO-8, so don't blank the sheet.
- Sprite sheet map: 1-13 projectiles/pickups/explosions (8x8), 32-42 player frames (16x16: idle, right, left, explode x3).
