# Validation scope for 0.1.3

The distributed circuit is byte-identical to the qualified 0.1.3 build.
All 173 corresponding Quartus source/configuration inputs are preserved exactly.
All four fitted corners pass setup, hold, recovery, removal and minimum pulse
width. Worst margins in that order: +0.352 / +0.043 / +2.234 / +0.436 / +0.651 ns.
Warnings, effective constraints, clocks and SDRAM register packing were reviewed.
Resource counts and exact source/bitstream hashes are in PROVENANCE.json.

A fresh 1,400-frame original-ROM integration run passed 24 automatic checks. Independent 35-capture review supports stage entry and a late-Up response. PCM tests matched 9,832 selection values and 19,022 service-AE values with nine signed wraps. Pocket comparisons confirm improved speech, while the colored logo wipe remains missing.

Simulation, fitted timing and physical observations are distinct. Original game
ROMs and factory EEPROM data were not patched to pass checks. Exact installed SD
bytes were not independently authenticated. No exhaustive full-game, every Dock
action, objective audio-fidelity or high-score-persistence result is claimed.
Private proof data and recordings are not distributed. This historical publication
and presentation update required no new Quartus build or gameplay replay.
