# Asterix — Analogue Pocket openFPGA

Standalone **Asterix (Konami, 1992), World EAD** for Analogue Pocket, by **mmmax4**.
Based on [jlrh/konami-fpga](https://github.com/jlrh/konami-fpga),
[JTCORES/JTFRAME](https://github.com/jotego/jtcores), and the Pocket integration
from [MooBucky / plasticbugs](https://github.com/plasticbugs/moomesa).

![Asterix title screen on Analogue Pocket](docs/images/title.png)

## Install

1. Copy the release's **Cores**, **Platforms** and **Assets** folders to the SD root.
2. Supply your own complete MAME **asterix / World EAD** ZIP and build the image:

   ```sh
   python3 scripts/build_rom.py /path/to/asterix.zip --output private/asterix.rom
   python3 scripts/verify_rom.py /path/to/asterix.zip private/asterix.rom
   ```

3. Copy the resulting `asterix.rom` to `Assets/asterix/mmmax4.asterix/` on the SD.
4. Close/reopen the core, then launch **Arcade → Asterix**. The sole game loads automatically.

The release contains **no game ROM, EEPROM dump or save**. Its builder/verifier
use Python 3's standard library and check all eleven required original dumps
by size, CRC32 and SHA1, including the factory EEPROM. Only World EAD is supported.
Keep an existing `asterix.sav`; see [installation and recovery](docs/INSTALL.md).

## Controls

| Pocket | Game |
| --- | --- |
| D-pad | Move |
| B / X | Punch |
| A / Y | Jump |
| Select | Coin |
| Start | Start / select |

Dock supports two players. Test and Service buttons start Unassigned; optional
assignments and Test Switch (hold) are in the core menu. Cabinet settings use
the original EEPROM-backed Test menu. Arcade 4:3 is default; Fill screen uses 10:9.

## Version 0.1.4

The KONAMI animated logo's centered vertical clipping is corrected. The user
confirmed the logo on Pocket with v014. The earlier v013 speech decoder fix is
retained unchanged; the user reported speech substantially improved, with
possible mild remaining saturation. This is not an objective full-audio-fidelity claim.

Earlier Pocket tests on OS 2.7 reported gameplay through level 2, EEPROM
initialization, direct startup and cabinet-setting persistence. High-score
persistence is **not supported**: this core saves the 128-byte EEPROM, not the
volatile score table. Full game completion and every two-player Dock action
have not been exhaustively verified.

The release uses the exact qualified/tested v014 bitstream. Validation combines
fresh targeted sprite tests and the historical v013 full-machine baseline;
no new v014 1,400-frame replay is claimed. See [validation](docs/VALIDATION.md).

The public package uses the same independently authored plain banner as the
previous publication preparation. The catalog marquee stays excluded because
its redistribution permission is not established. The title screenshot above
is the user's Pocket capture, included at their explicit request; no other
private screenshots, recordings or messages are bundled.

See [build instructions](docs/BUILD.md), [credits](CREDITS.md),
[licensing and permission scope](LICENSING.md), and [provenance](docs/PROVENANCE.json).
Game names, characters and artwork remain their respective owners' works.
