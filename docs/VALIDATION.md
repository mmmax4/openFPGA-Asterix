# Validation scope for 0.1.4

The distributed FPGA circuit is byte-identical to the qualified private v014
bitstream. Its 173 corresponding Quartus inputs are preserved exactly.

All four reported corners pass setup, hold, recovery, removal and minimum pulse
width; worst margins are +0.352 / +0.127 / +2.709 / +0.431 / +0.651 ns. All 116
clock checks, 20 TNS summaries and 12,000 supplemental setup destinations pass,
with zero TNS/unconstrained counts. Warnings, constraints, 407 protected originals,
selected aliases, 16 SDRAM pin triples and clock transfers were reviewed.
Resources: 8,524/18,480 ALMs; 14,200 registers; 152/308 M10Ks;
1,178,528 memory bits; 21/66 DSPs; 2/4 PLLs.

V014 changes only the scanner relative to the qualified v013 circuit. Fresh
coverage checks 14,664 centered vertical-clip conditions, actual original-ROM
object/DMA/MMR/draw/line-buffer masks of 224/14/0 lines, an old-v013 negative
counterexample with 124,992 mismatched pixels, and 288 ordinary cases preserving
320 draw starts/digest. The independent targeted renderer and fitted reviews pass.
Full horizontal clip, full RGB/sprite priority overlap and exhaustive gameplay
are not established by those tests.

The immutable historical v013 integration baseline completed 1,400 frames and
24 automatic checks on 95 inputs, with original POST and 128 palette words. Its
35-capture review supports stage entry and a late-Up response; other five action
effects and complete combat/stage completion were not visually proven. No fresh
v014 1,400-frame replay was run and historical source identities were not rewritten.
Current unchanged PCM proofs include selection voice 9,832 values and service
AE 19,022 values with nine signed-wrap events, without changing game ROM data.

Physical observations remain separate: the user confirmed the v014 KONAMI logo
on Pocket, reported substantially improved v013 speech with possible mild remaining
saturation, and previously reported EEPROM initialization, cabinet settings
persisting, direct startup and gameplay to level 2 on OS 2.7. Exact installed SD
bytes were not independently authenticated. The v014 video was catalogued only,
as requested; no playback/analysis claim is made. No exhaustive full-game, Dock,
objective audio fidelity or high-score persistence result is claimed.

Source/binary/capture review provenance is explicit: independent agents reviewed
v014 renderer and fit; the lead performed the final private v014 actual-file audit
after the earlier package agent reached its usage limit. This publication
preparation also performs a direct algorithmic actual-file/hash audit and is
not an additional model-peer or new physical test. Private proof data stays private.
