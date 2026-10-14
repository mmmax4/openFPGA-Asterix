#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
quartus_dir=${QUARTUS_BIN:-/opt/intelFPGA_lite/21.1/quartus/bin}
cd "$root/src/projects"
run_stage() {
  local stage=$1
  shift
  python3 "$root/scripts/build_inputs.py" begin "$stage"
  if [ "$stage" = sta ]; then
    # TimeQuest does not accept the map/fit/asm settings-file options.
    "$quartus_dir/quartus_sta" asterix_pocket "$@"
  else
    "$quartus_dir/quartus_$stage" asterix_pocket --read_settings_files=on --write_settings_files=off "$@"
  fi
  python3 "$root/scripts/build_inputs.py" end "$stage"
}
refit() {
  run_stage fit
  run_stage asm
  run_stage sta --do_report_timing
}
case "${1:-compile}" in
 compile) run_stage map; refit ;;
 map) run_stage map ;;
 refit) refit ;;
 sta) run_stage sta --do_report_timing ;;
 *) echo 'usage: bash scripts/build.sh [compile|map|refit|sta]' >&2; exit 2 ;;
esac
