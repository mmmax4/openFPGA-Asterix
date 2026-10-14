#!/usr/bin/env python3
"""Capture and recheck the exact inputs and outputs of each Quartus stage."""
import hashlib
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SUFFIXES = {'.v', '.sv', '.svh', '.mem', '.mif', '.qip', '.qsf', '.sdc', '.qpf', '.tcl'}
REPORTS = {'map': ['map.summary', 'map.rpt'], 'fit': ['fit.summary', 'fit.rpt'],
           'sta': ['sta.summary', 'sta.rpt'], 'asm': ['asm.rpt', 'rbf']}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture():
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted((ROOT/'src').rglob('*'))
            if p.is_file() and p.suffix in SUFFIXES and
            not {'db', 'incremental_db', 'output_files'} & set(p.relative_to(ROOT/'src').parts)}


def main():
    action, stage = sys.argv[1:]
    if action not in {'begin', 'end'} or stage not in REPORTS:
        raise SystemExit('usage: build_inputs.py begin|end map|fit|asm|sta')
    destination = ROOT/'build'/f'quartus-inputs-{stage}.json'
    destination.parent.mkdir(exist_ok=True)
    current = capture()
    if action == 'begin':
        result = {'stage': stage, 'started_ns': time.time_ns(), 'sources': current,
                  'completed': False, 'sources_unchanged': False}
    else:
        result = json.loads(destination.read_text())
        result['sources_unchanged'] = result['sources'] == current
        result['finished_ns'] = time.time_ns()
        outputs = [ROOT/'src/projects/output_files'/('asterix_pocket.'+s) for s in REPORTS[stage]]
        result['reports'] = {p.relative_to(ROOT).as_posix(): digest(p) for p in outputs}
        result['outputs_created_during_stage'] = all(p.stat().st_mtime_ns >= result['started_ns'] for p in outputs)
        result['completed'] = result['sources_unchanged'] and result['outputs_created_during_stage']
    destination.write_text(json.dumps(result, indent=2)+'\n')
    if action == 'end' and not result['completed']:
        raise SystemExit(f'{stage}: changed inputs or stale outputs')
    # Finish and bind the current stage before stopping a sequential build.
    # This permits a required source correction without editing active inputs
    # or starting another Quartus process alongside the current one.
    if action == 'end' and (ROOT/'build/quartus-stop-requested').exists():
        raise SystemExit(f'{stage}: completed; stop requested before the next stage')


if __name__ == '__main__':
    main()
