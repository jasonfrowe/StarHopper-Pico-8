# Star Hopper PICO-8 port

- Source game (C, llvm-mos, RP6502): `/Users/rowe/Software/rp6502/RPDemo` (`src/`, `Sprites/`). Behavior reference for the port.
- Code lives in `src/*.lua`, pulled into `starhopper.p8` via `#include` (not recursive; add new files to the cart's `__lua__` list).
- Style: lowercase only, one-space indents, PICO-8 shorthand (`if (c) x`, `+=`), globals are fine. Watch the 8192-token budget.
- Verify changes with `python3 tools/snap.py --frames N [--each "lua"]` and view the PNG it saves; `--each` can fake input or state.
- `tools/import_gfx.py` owns only the sprite cells in its `LAYOUT`; other cells may be hand-drawn in PICO-8, so don't blank the sheet.
- All sprites are 8x8 (bosses are 3x2 blocks). The sheet map is at the top of `tools/import_gfx.py`; sprites 128-255 are used, so never use the map.
- Speeds and positions: the rp6502 value x 0.4.
- Music: one cart per tune in `music/`, loaded with `music_play(name)` (`src/music.lua`). Sfx 0-51 belong to music, 52-63 to game sound effects.
