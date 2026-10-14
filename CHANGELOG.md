# Changelog

## 0.1.4

- Correct centered vertical clipping for highly zoomed sprites, restoring the colored KONAMI logo animation. Confirmed on Pocket.

Some speech passages may retain mild distortion.

## 0.1.3

- Correct PPCM nibble sequencing and signed accumulator wrapping, improving speech quality.
- Correct large-zoom sprite geometry with a pipelined scanner.

The colored KONAMI logo wipe is still missing; fixed in 0.1.4. Some speech passages may retain mild distortion.

## 0.1.2

- Playable standalone World EAD core in the Arcade category.
- Automatic startup without the initial game-selection screen.
- EEPROM-backed cabinet settings and initialization through Test Switch (hold) and Reset Core.

The animated KONAMI logo fill is incorrect and some speech passages sound distorted. These issues are fixed or improved in later releases.

## High-score persistence

High scores and entered names are stored in working RAM, and the original
program restores the default score table at startup. The EEPROM contains
cabinet settings, not scores. Persistent high scores would require a separate
RAM save/restore feature, which this core does not implement.
