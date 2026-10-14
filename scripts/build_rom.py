#!/usr/bin/env python3
"""Build the private Asterix World EAD Pocket image from a verified MAME ZIP.

Only Python's standard library is needed. All offsets are byte offsets and the
Pocket download path stores the first byte of each pair in SDRAM bits [15:8].
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
MAME_SNAPSHOT_SHA256 = "878bde634f5610265273ea5d4852f7e0cad3ce15d078c4ec81090311861d45f1"
# ROM_START(asterix), MAME src/mame/konami/asterix.cpp; World ver. EAD.
PARTS = {
    "068_ea_d01.8c": (0x20000, "61d6621d", "908a344e9bbce0c7544bd049494258d1d3ad073b"),
    "068_ea_d02.8d": (0x20000, "53aac057", "7401ca5b70f384688c3353fc1ac9ef0b27814c66"),
    "068a03.7c": (0x20000, "8223ebdc", "e4aa39e4bc1d210bdda5b0cb41d6c8006c48dd24"),
    "068a04.7d": (0x20000, "9f351828", "e03842418f08e6267eeea03362450da249af73be"),
    "068_a05.5f": (0x10000, "d3d0d77b", "bfa77a8bf651dc27f481e96a2d63242084cc214c"),
    "068a12.16k": (0x80000, "b9da8e9c", "a46878916833923e421da0667e37620ae0b77744"),
    "068a11.12k": (0x80000, "7eb07a81", "672c0c60834df7816d33d88643e4575b8ca9bcc1"),
    "068a08.7k": (0x200000, "c41278fe", "58e5f67a67ae97e0b264489828cd7e74662c5ed5"),
    "068a07.3k": (0x200000, "32efdbc4", "b7e8610aa22249176d82b750e2549d1eea6abe4f"),
    "068a06.1e": (0x200000, "6df9ec0e", "cee60312e9813bd6579f3ac7c3c2521a8e633eca"),
    "asterix.nv": (0x80, "490085c8", "2a79e7c79db4b4fb0e6a7249cfd6a57e74b170e3"),
}


def hashes(data):
    return {"size": len(data), "crc32": f"{zlib.crc32(data) & 0xffffffff:08x}",
            "sha1": hashlib.sha1(data).hexdigest(), "sha256": hashlib.sha256(data).hexdigest()}


def read_verified(archive):
    parts, records = {}, {}
    with zipfile.ZipFile(archive) as source:
        members = source.infolist()
        for name, (size, crc, sha1) in PARTS.items():
            candidates = [entry for entry in members if not entry.is_dir()
                          and Path(entry.filename).name.lower() == name.lower()]
            for entry in candidates:
                if entry.file_size != size or entry.CRC != int(crc, 16):
                    continue
                data = source.read(entry)
                actual = hashes(data)
                if actual["sha1"] == sha1:
                    parts[name] = data
                    records[name] = {"archive_member": entry.filename, **actual}
                    break
            if name not in parts:
                raise ValueError(f"Missing or incorrect World EAD part {name}: "
                                 f"need size {size:#x}, CRC32 {crc}, SHA1 {sha1}")
    return parts, records


def graphics(high_half, low_half):
    """ROM_LOAD32_WORD little-endian numeric value -> big-endian image bytes."""
    result = bytearray(len(high_half) + len(low_half))
    result[0::4], result[1::4] = high_half[1::2], high_half[0::2]
    result[2::4], result[3::4] = low_half[1::2], low_half[0::2]
    return bytes(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", nargs="?", type=Path, default=ROOT / "asterix.zip")
    parser.add_argument("--output", type=Path, default=ROOT / "private/asterix.rom")
    parser.add_argument("--evidence", type=Path, default=ROOT / "evidence/rom-identity.json")
    args = parser.parse_args()
    parts, records = read_verified(args.archive)
    maincpu = bytearray(b"\xff" * 0x100000)
    for offset, even, odd in [(0, "068_ea_d01.8c", "068_ea_d02.8d"),
                              (0x80000, "068a03.7c", "068a04.7d")]:
        maincpu[offset:offset + 0x40000:2] = parts[even]
        maincpu[offset + 1:offset + 0x40000:2] = parts[odd]
    regions = [
        ("sprites", 0x000000, graphics(parts["068a07.3k"], parts["068a08.7k"])),
        ("tiles", 0x400000, graphics(parts["068a11.12k"], parts["068a12.16k"])),
        ("pcm", 0x600000, parts["068a06.1e"]),
        ("maincpu", 0x800000, bytes(maincpu)),
        ("audiocpu", 0x900000, parts["068_a05.5f"]),
        ("eeprom", 0x910000, parts["asterix.nv"]),
    ]
    image = bytearray(b"\xff" * 0x910080)
    for _, offset, data in regions:
        image[offset:offset + len(data)] = data
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)
    record = {
        "schema": 1, "set": "asterix", "revision": "World EAD", "private": True,
        "mame_snapshot_sha256": MAME_SNAPSHOT_SHA256,
        "archive": {"path": str(args.archive), **hashes(args.archive.read_bytes())},
        "parts": records,
        "image": {"path": str(args.output), "byte_order": "big-endian SDRAM words", **hashes(image)},
        "regions": {name: {"offset": offset, **hashes(data)} for name, offset, data in regions},
        "padding": [{"offset": 0x500000, "size": 0x100000, "value": "ff"},
                    {"offset": 0x840000, "size": 0x40000, "value": "ff"},
                    {"offset": 0x8c0000, "size": 0x40000, "value": "ff"}],
        "eeprom_policy": "Provided MAME default preserved byte-for-byte; no patching.",
        "verification": {"status": "builder-identity-only; run verify_rom.py for independent verification"},
    }
    args.evidence.parent.mkdir(parents=True, exist_ok=True)
    args.evidence.write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"output": str(args.output), **hashes(image)}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile, KeyError) as error:
        sys.exit(f"error: {error}")
