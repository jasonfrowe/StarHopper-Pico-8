# Star Hopper PICO-8 port

- Source game (C, llvm-mos, RP6502): `/Users/rowe/Software/rp6502/RPDemo` (`src/`, `Sprites/`). Behavior reference for the port.
- Code lives in `src/*.lua`, pulled into `starhopper.p8` via `#include` (not recursive; add new files to the cart's `__lua__` list).
- Style: lowercase only, one-space indents, PICO-8 shorthand (`if (c) x`, `+=`), globals are fine. Watch the 8192-token budget.
- Verify changes with `python3 tools/snap.py --frames N [--each "lua"]` and view the PNG it saves; `--each` can fake input or state.
- `tools/import_gfx.py` owns only the sprite cells its `layout()` writes; other cells may be hand-drawn in PICO-8, so don't blank the sheet.
- All sprites are 8x8 (bosses are 3x2 blocks). The sheet map is at the top of `tools/import_gfx.py`; sprites 128-255 are used, so never use the map.
- Coordinates: x = rp6502 x * 0.4; y = 8 + (rp6502 y - 24) * 5/9 (8px hud strip, then the 216px playfield in 120px). Speeds = rp6502 px/frame * 0.45.
- Score is a 32-bit integer stored >>16 (`score_add`, `tostr(score,2)`); PICO-8 numbers overflow past 32767, including loop counters.
- Budget: `python3 tools/tokens.py` (approximate; errs high). Headless play-through: `python3 tools/snap.py --frames 20000 --each @tools/autopilot.lua` (max 32767 frames; add `start_level(n)` to begin later).
- Hand-drawn replacements for imported cells go in `HAND` in `tools/import_gfx.py`.
- Music: one cart per tune in `music/`, loaded with `music_play(name)` (`src/music.lua`). Sfx 0-51 belong to music, 52-63 to game sound effects.
- Boss weak spots are colour 15 in the sheet; `_draw` maps 15->5 (grey) and `boss_draw` recolours it yellow/red. Bosses test headless via `tools/bosstest.lua`.
- The title logo is stored in the upper map (0x2000, 64-byte rows) by `import_gfx.py`; `title_start` memcpys it over sheet rows 64+ and `new_game` reloads them. Don't use the map for anything else.
- High score: `cartdata("jasonrowe_starhopper")`, slot 0, stored >>16 like the score.
- Game flow states live in `main.lua` (title, play, clear, bonus, failed, over, win).
