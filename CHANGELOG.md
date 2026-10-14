# Changelog

## 0.1.3

- Correct forward PPCM nibble order and signed accumulator wrapping.
- Speech quality substantially improved in Pocket comparisons; mild distortion may remain.
- Update large-sprite vertical geometry and pipeline the sprite scanner.
- Known issue: the colored KONAMI logo wipe is still missing; fixed in 0.1.4.
- Automatic startup, original marquee and cabinet EEPROM persistence retained.

## 0.1.2

- Playable historical baseline in the Arcade category.
- Automatic loading of Asterix (World EAD), without the initial selection screen.
- Original platform marquee and EEPROM-backed cabinet settings.
- EEPROM initialization through Test Switch (hold) and Reset Core.
- Known issues: KONAMI logo animation and metallic speech; fixed or improved in later releases.

All releases include a compiled ROM-free core, the World EAD ROM builder,
preserved source licenses and credits. Only the 128-byte cabinet EEPROM is saved;
high-score persistence and save states are not implemented.
