# Validation scope for 0.1.4

The distributed circuit is byte-identical to the qualified 0.1.4 build.
All 173 corresponding Quartus source/configuration inputs are preserved exactly.
All four fitted corners pass setup, hold, recovery, removal and minimum pulse
width. Worst margins in that order: +0.352 / +0.127 / +2.709 / +0.431 / +0.651 ns.
Warnings, effective constraints, clocks and SDRAM register packing were reviewed.
Resource counts and exact source/bitstream hashes are in PROVENANCE.json.

Only the sprite scanner changes from 0.1.3. Fresh coverage passes 14,664 centered-clip cases and original-ROM DMA/MMR/draw masks of 224/14/0 lines, rejects the old scanner and preserves 288 ordinary cases. The historical 0.1.3 1,400-frame integration baseline is retained; no new 0.1.4 full-machine replay is claimed. The corrected logo animation is confirmed on Pocket.

Simulation, fitted timing and physical observations are distinct. Original game
ROMs and factory EEPROM data were not patched to pass checks. Exact installed SD
bytes were not independently authenticated. No exhaustive full-game, every Dock
action, objective audio-fidelity or high-score-persistence result is claimed.
Private proof data and recordings are not distributed. This historical publication
and presentation update required no new Quartus build or gameplay replay.
