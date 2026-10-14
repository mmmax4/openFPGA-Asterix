# Validation scope for 0.1.2

The distributed circuit is byte-identical to the qualified 0.1.2 build.
All 173 corresponding Quartus source/configuration inputs are preserved exactly.
All four fitted corners pass setup, hold, recovery, removal and minimum pulse
width. Worst margins in that order: +0.369 / +0.120 / +3.771 / +0.505 / +0.651 ns.
Warnings, effective constraints, clocks and SDRAM register packing were reviewed.
Resource counts and exact source/bitstream hashes are in PROVENANCE.json.

The unchanged earlier 1,400-frame original-ROM integration baseline and metadata-sensitive loader checks pass. Pocket tests confirmed direct startup and EEPROM settings; earlier gameplay reached level 2. Speech and the animated logo have known issues.

Simulation, fitted timing and physical observations are distinct. Original game
ROMs and factory EEPROM data were not patched to pass checks. Exact installed SD
bytes were not independently authenticated. No exhaustive full-game, every Dock
action, objective audio-fidelity or high-score-persistence result is claimed.
Private proof data and recordings are not distributed. This historical publication
and presentation update required no new Quartus build or gameplay replay.
