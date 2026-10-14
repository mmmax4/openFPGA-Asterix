# Asterix 0.1.3 — ROM-free release

Asterix (Konami, 1992), World EAD, for Analogue Pocket openFPGA.

## Changes in 0.1.3

- Correct forward PPCM nibble order and signed accumulator wrapping.
- Speech quality substantially improved in Pocket comparisons; mild distortion may remain.
- Update large-sprite vertical geometry and pipeline the sprite scanner.
- Known issue: the colored KONAMI logo wipe is still missing; fixed in 0.1.4.
- Automatic startup, original marquee and cabinet EEPROM persistence retained.

Download **mmmax4.asterix-v0.1.3.zip** for the SD-card package. It includes the
compiled core, original platform marquee, ROM builder and no game ROM or save.
Copy Cores, Platforms and Assets to the SD root. Build and verify `asterix.rom`
from your own complete MAME World EAD ZIP, then copy it to
`Assets/asterix/mmmax4.asterix/`. Preserve an existing `asterix.sav`.

Cabinet EEPROM settings are saved; high scores and save states are not implemented.
Full-game completion and every Dock action have not been exhaustively verified.
The FPGA circuit is unchanged from the qualified 0.1.3 build. This publication
does not involve a new compilation or gameplay simulation.

GitHub supplies **Source code (zip/tar.gz)** from the release tag; no duplicate
source ZIP is uploaded. SHA256SUMS covers the compiled package. Installation,
controls and the version history are in the repository README and CHANGELOG.

Thanks to plasticbugs/Scott, jlrh, Jotego/JTFRAME, Marcus Andrade/OpenGateware,
FX68K/T80 contributors and all original authors. Existing notices and terms remain.
