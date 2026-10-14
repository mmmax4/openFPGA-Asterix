#!/usr/bin/env python3
"""Generate a plain independently authored native Pocket platform banner."""
# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path

FONT = {
 'A': ['01110','10001','10001','11111','10001','10001','10001'],
 'S': ['01111','10000','10000','01110','00001','00001','11110'],
 'T': ['11111','00100','00100','00100','00100','00100','00100'],
 'E': ['11111','10000','10000','11110','10000','10000','11111'],
 'R': ['11110','10001','10001','11110','10100','10010','10001'],
 'I': ['11111','00100','00100','00100','00100','00100','11111'],
 'X': ['10001','10001','01010','00100','01010','10001','10001'],
}

def main():
    width, height, scale = 521, 165, 10
    canvas = bytearray([224]) * (width * height)
    word = 'ASTERIX'
    left = (width - (6 * len(word) - 1) * scale) // 2
    top = (height - 7 * scale) // 2
    for index, letter in enumerate(word):
        for row, bits in enumerate(FONT[letter]):
            for column, bit in enumerate(bits):
                if bit == '1':
                    for dy in range(scale):
                        start = (top + row * scale + dy) * width + left + (index * 6 + column) * scale
                        canvas[start:start + scale] = bytes([32]) * scale
    native = bytearray(width * height * 2)
    for y in range(height):
        for x in range(width):
            native[2 * ((width - 1 - x) * height + y)] = 255 - canvas[y * width + x]
    p = Path(__file__).resolve().parents[1] / 'pkg/pocket/Platforms/_images/asterix.bin'
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(native)

if __name__ == '__main__':
    main()
