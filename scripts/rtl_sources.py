#!/usr/bin/env python3
"""One explicit source list for simulation and Quartus."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def sources():
    paths = list((ROOT/'src/upstream/asterix').glob('*.v')) + list((ROOT/'src/upstream/asterix').glob('*.sv'))
    skip = ['cpu_j68.v','header.v','j68_test.v','jtframe_j68.v']
    paths += [p for p in (ROOT/'src/upstream/jt').glob('*.v') if p.name not in skip and not p.name.startswith('j68_')]
    for d in ['cpu-fx68k', 'sound-jt51', 'eeprom-jteeprom']:
        paths += list((ROOT/'src/modules'/d).glob('*.v')) + list((ROOT/'src/modules'/d).glob('*.sv'))
    paths += list((ROOT/'src/rtl').glob('*.sv'))
    return sorted(paths)

def main():
    lines = ['# Generated from scripts/rtl_sources.py; same sources as simulation.']
    for p in sources():
        lang = 'SYSTEMVERILOG_FILE' if p.suffix == '.sv' else 'VERILOG_FILE'
        lines.append(f'set_global_assignment -name {lang} [file join $::quartus(qip_path) "{"../"+p.relative_to(ROOT/"src").as_posix()}"]')
    (ROOT/'src/rtl/index.qip').write_text('\n'.join(lines)+'\n')
    print(f'{len(sources())} RTL sources')

if __name__ == '__main__':
    main()
