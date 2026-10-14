# Installation and EEPROM recovery

Copy the ROM-free release's Cores, Platforms and Assets folders onto the SD root.
Build/verify your own complete MAME asterix World EAD ZIP with the supplied Python
scripts, then place `asterix.rom` in `Assets/asterix/mmmax4.asterix/`.

Preserve an existing `asterix.sav`, close/reopen the core and launch Arcade → Asterix.
The named game instance is optional; fixed ROM/save filenames support automatic
loading. No save is installed, renamed or deleted by the release. Without an
existing save, the original 128-byte factory EEPROM from the locally built image
is retained. The ordinary-slot fallback save path is
`Saves/asterix/common/asterix.sav`; preserve an existing instance-based save location.

If an old invalid save causes 17B BAD, back it up if cabinet settings matter,
enable Test Switch (hold), then select Reset Core. Expect EEPROM INITIALIZE
COMPLETE, release Test and reset again to confirm normal self-test/title.
The original initializer restores cabinet defaults; its operation was confirmed
on the earlier Pocket build. Report repeated EEPROM BIT CHECK BAD as a failure.

Wait until the level introduction finishes before testing movement/punch/jump.
Compare the full no-credit KONAMI sequence and selection speech; for audio,
SOUND CHECK 98/AE/AF are useful comparison cases. Cabinet settings
are managed in the original Test menu. Only the EEPROM is saved; high-score
persistence and save states are not implemented. OS metadata requires 2.0;
Pocket tests used OS 2.7.
