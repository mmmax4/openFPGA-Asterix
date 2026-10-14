#!/usr/bin/env python3
"""Reverse bits within each byte of a Quartus RBF for Pocket openFPGA."""
# SPDX-License-Identifier: GPL-3.0-or-later
import argparse
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('raw',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
data=a.raw.read_bytes()
if not data:raise SystemExit('Empty RBF')
if a.output.exists():raise SystemExit('Refuse to overwrite existing output')
reverse=bytes(sum(((v>>i)&1)<<(7-i) for i in range(8)) for v in range(256))
a.output.write_bytes(data.translate(reverse))
