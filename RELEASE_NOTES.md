# Asterix 0.1.4 — ROM-free release

Asterix (Konami, 1992), World EAD, for Analogue Pocket openFPGA.

## Changes in 0.1.4

- Correct centered vertical clipping for highly zoomed sprites, restoring the colored KONAMI logo animation. Confirmed on Pocket.

## Known limitations

Some speech passages may retain mild distortion.

High scores and entered names are stored in working RAM, and the original
program restores the default score table at startup. The EEPROM contains
cabinet settings, not scores. Persistent high scores would require a separate
RAM save/restore feature, which this core does not implement.
Save states are not implemented.

## Installation

Download **mmmax4.asterix-v0.1.4.zip** and follow the
[installation instructions](https://github.com/mmmax4/openFPGA-Asterix/blob/main/docs/INSTALL.md).
Supply your own complete MAME `asterix.zip`; the ROM builder is included.
No game ROM or save is bundled.
