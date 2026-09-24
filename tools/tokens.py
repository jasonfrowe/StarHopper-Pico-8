#!/usr/bin/env python3
"""Approximate PICO-8 token count for the cart's included Lua files.

Follows PICO-8's rules closely enough to track the 8192 budget: every name,
literal and operator is one token, except `,` `.` `:` `;` `)` `]` `}` `end`
and `local`, which are free. (A minus sign before a number is free in PICO-8
but counted here, so this errs slightly high.) PICO-8's own count (the pico8-ls extension, or `info` in the console) is
authoritative.

Usage:  python3 tools/tokens.py
"""
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
LIMIT = 8192

TOKEN = re.compile(r"""
    --\[(=*)\[.*?\]\1\]      |   # long comment
    --[^\n]*                 |   # line comment
    \[(=*)\[.*?\]\2\]        |   # long string
    "(?:\\.|[^"\\])*"        |   # string
    '(?:\\.|[^'\\])*'        |
    0x[0-9a-fA-F.]+          |   # hex number
    0b[01.]+                 |
    \d+\.?\d*|\.\d+          |   # number
    [A-Za-z_][A-Za-z_0-9]*   |   # name
    \.\.\.|\.\.=?|[-+*/%^\\&|<>=!~]=|>>>=?|<<>|>><|>>|<<|::|[^\s]
""", re.S | re.X)
FREE = {",", ".", ":", ";", ")", "]", "}", "end", "local"}


def count(src):
    n = 0
    prev = None
    for m in TOKEN.finditer(src):
        tok = m.group(0)
        if tok.startswith("--"):
            continue
        if tok in FREE:
            prev = tok
            continue
        n += 1
        prev = tok
    return n


def main():
    cart = open(os.path.join(ROOT, "starhopper.p8")).read()
    lua = cart.split("__lua__\n", 1)[1].split("\n__", 1)[0]
    total = count(re.sub(r"^\s*#include.*$", "", lua, flags=re.M))
    for inc in re.findall(r"^\s*#include\s+(\S+)", lua, re.M):
        n = count(open(os.path.join(ROOT, inc)).read())
        total += n
        print(f"{n:6d}  {inc}")
    print(f"{total:6d}  total ({total * 100 // LIMIT}% of {LIMIT})")


if __name__ == "__main__":
    main()
