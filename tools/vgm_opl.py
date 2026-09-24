"""Minimal OPL2 (YM3812) VGM reader: per-channel note events with timing."""
import math
import struct

VGM_RATE = 44100


def read_vgm(path):
    """Return (events, total_samples, loop_sample).

    events: list of (sample_time, kind, channel, value) where kind is
    'on' (value = (midi_note, carrier total level 0..63, 0 = loudest)) or 'off'.
    """
    b = open(path, "rb").read()
    assert b[:4] == b"Vgm ", path
    version = struct.unpack_from("<I", b, 8)[0]
    total = struct.unpack_from("<I", b, 0x18)[0]
    loop_off = struct.unpack_from("<I", b, 0x1C)[0]
    loop_abs = loop_off + 0x1C if loop_off else None
    data = 0x34 + struct.unpack_from("<I", b, 0x34)[0] if version >= 0x150 else 0x40

    regs = [0] * 256
    keyed = [False] * 9
    events = []
    t = 0
    loop_t = None
    p = data
    while p < len(b):
        if loop_abs is not None and p == loop_abs:
            loop_t = t
        c = b[p]
        if c == 0x5A:  # YM3812 write
            r, v = b[p + 1], b[p + 2]
            p += 3
            regs[r] = v
            if 0xB0 <= r <= 0xB8:
                ch = r - 0xB0
                on = bool(v & 0x20)
                if on and not keyed[ch]:
                    events.append((t, "on", ch, _note(regs, ch)))
                elif not on and keyed[ch]:
                    events.append((t, "off", ch, None))
                keyed[ch] = on
        elif c == 0x61:
            t += struct.unpack_from("<H", b, p + 1)[0]; p += 3
        elif c == 0x62:
            t += 735; p += 1
        elif c == 0x63:
            t += 882; p += 1
        elif 0x70 <= c <= 0x7F:
            t += (c & 15) + 1; p += 1
        elif c == 0x66:
            break
        elif c in (0x4F, 0x50):
            p += 2
        elif 0x51 <= c <= 0x5F:
            p += 3
        elif c == 0x67:
            p += 7 + struct.unpack_from("<I", b, p + 3)[0]
        else:
            raise ValueError(f"{path}: unhandled VGM command {c:#x} at {p:#x}")
    return events, total, loop_t


# OPL2 operator offsets for each channel's carrier (operator 2)
CARRIER = [3, 4, 5, 11, 12, 13, 19, 20, 21]


def _note(regs, ch):
    fnum = regs[0xA0 + ch] | ((regs[0xB0 + ch] & 3) << 8)
    block = (regs[0xB0 + ch] >> 2) & 7
    freq = fnum * 49716 / 2 ** (20 - block)
    midi = round(69 + 12 * math.log2(freq / 440)) if freq > 0 else 0
    return midi, regs[0x40 + CARRIER[ch]] & 63
