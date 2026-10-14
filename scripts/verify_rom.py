#!/usr/bin/env python3
"""Independently check a Pocket image by reconstructing MAME address lanes.

No imports from the image builder. Optionally check the original MiSTer MRA
using its standard right-to-left map semantics and the Pocket byte order.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
# Independent transcription of ROM_START(asterix), including address offsets.
SPEC = [
    ("maincpu", "068_ea_d01.8c", 0, 0x20000, 2, "61d6621d", "908a344e9bbce0c7544bd049494258d1d3ad073b"),
    ("maincpu", "068_ea_d02.8d", 1, 0x20000, 2, "53aac057", "7401ca5b70f384688c3353fc1ac9ef0b27814c66"),
    ("maincpu", "068a03.7c", 0x80000, 0x20000, 2, "8223ebdc", "e4aa39e4bc1d210bdda5b0cb41d6c8006c48dd24"),
    ("maincpu", "068a04.7d", 0x80001, 0x20000, 2, "9f351828", "e03842418f08e6267eeea03362450da249af73be"),
    ("audiocpu", "068_a05.5f", 0, 0x10000, 1, "d3d0d77b", "bfa77a8bf651dc27f481e96a2d63242084cc214c"),
    ("tiles", "068a12.16k", 0, 0x80000, 4, "b9da8e9c", "a46878916833923e421da0667e37620ae0b77744"),
    ("tiles", "068a11.12k", 2, 0x80000, 4, "7eb07a81", "672c0c60834df7816d33d88643e4575b8ca9bcc1"),
    ("sprites", "068a08.7k", 0, 0x200000, 4, "c41278fe", "58e5f67a67ae97e0b264489828cd7e74662c5ed5"),
    ("sprites", "068a07.3k", 2, 0x200000, 4, "32efdbc4", "b7e8610aa22249176d82b750e2549d1eea6abe4f"),
    ("pcm", "068a06.1e", 0, 0x200000, 1, "6df9ec0e", "cee60312e9813bd6579f3ac7c3c2521a8e633eca"),
    ("eeprom", "asterix.nv", 0, 0x80, 1, "490085c8", "2a79e7c79db4b4fb0e6a7249cfd6a57e74b170e3"),
]
REGIONS = {"sprites": (0, 0x400000), "tiles": (0x400000, 0x100000),
           "pcm": (0x600000, 0x200000), "maincpu": (0x800000, 0x100000),
           "audiocpu": (0x900000, 0x10000), "eeprom": (0x910000, 0x80)}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def same(actual, expected, label):
    if actual != expected:
        for offset, (left, right) in enumerate(zip(actual, expected)):
            if left != right:
                raise ValueError(f"{label}: mismatch at byte {offset:#x}")
        raise ValueError(f"{label}: length mismatch {len(actual):#x} != {len(expected):#x}")


def mra_bytes(node, blobs):
    if node.tag == "part":
        name = node.get("name")
        if name:
            data = blobs[name]
            require(f"{zlib.crc32(data) & 0xffffffff:08x}" == node.get("crc"), f"MRA CRC: {name}")
            start = int(node.get("offset", "0"), 0)
            return data[start:start + int(node.get("length", str(len(data) - start)), 0)]
        return bytes.fromhex(node.text or "") * int(node.get("repeat", "1"), 0)
    require(node.tag == "interleave", f"Unsupported MRA node {node.tag}")
    width = int(node.attrib["output"]) // 8
    lanes, count = {}, None
    for part in node:
        data = mra_bytes(part, blobs)
        mapping = list(reversed(part.attrib["map"]))
        stride = sum(digit != "0" for digit in mapping)
        require(len(mapping) == width and stride > 0 and len(data) % stride == 0, "Invalid MRA map")
        words = len(data) // stride
        require(count is None or count == words, "MRA sources have unequal lengths")
        count = words
        for lane, digit in enumerate(mapping):
            if digit != "0":
                require(lane not in lanes, "Overlapping MRA lanes")
                lanes[lane] = data[int(digit) - 1::stride]
    require(len(lanes) == width, "Incomplete MRA interleave")
    result = bytearray(width * count)
    for lane, data in lanes.items():
        result[lane::width] = data
    return bytes(result)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", nargs="?", type=Path, default=ROOT / "asterix.zip")
    parser.add_argument("image", nargs="?", type=Path, default=ROOT / "private/asterix.rom")
    parser.add_argument("--mra", type=Path, help="Original jlrh Asterix EAD MRA for independent map cross-check")
    parser.add_argument("--mame-source", type=Path, help="Check the pinned local MAME snapshot and declarations")
    parser.add_argument("--evidence", type=Path, help="Merge verification into the builder identity JSON")
    args = parser.parse_args()
    blobs, mame = {}, {name: bytearray(b"\xff" * size) for name, (_, size) in REGIONS.items()}
    with zipfile.ZipFile(args.archive) as archive:
        for region, name, offset, size, stride, crc, sha1 in SPEC:
            options = [entry for entry in archive.infolist() if Path(entry.filename).name == name
                       and entry.file_size == size and entry.CRC == int(crc, 16)]
            require(bool(options), f"Missing or incorrect part {name}")
            data = next((archive.read(entry) for entry in options
                         if hashlib.sha1(archive.read(entry)).hexdigest() == sha1), None)
            require(data is not None, f"SHA1 mismatch: {name}")
            require(zlib.crc32(data) & 0xffffffff == int(crc, 16), f"CRC mismatch: {name}")
            blobs[name] = data
            # Reconstruct MAME's region image without the builder's graphics helper.
            if stride == 4:
                mame[region][offset:offset + size * 2:4] = data[0::2]
                mame[region][offset + 1:offset + size * 2:4] = data[1::2]
            else:
                mame[region][offset:offset + size * stride:stride] = data
    image = args.image.read_bytes()
    require(len(image) == 0x910080, f"Image length {len(image):#x}, expected 0x910080")
    checked = []
    for name, (base, size) in REGIONS.items():
        stored = image[base:base + size]
        if name in ("sprites", "tiles"):
            # SDRAM word 0 -> high half, word 1 -> low half; jtasterix receives
            # {word0, word1}. Its numeric value equals little-endian MAME u32.
            for lane in range(4):
                same(stored[lane::4], bytes(mame[name][3 - lane::4]), f"{name} lane {lane}")
        else:
            same(stored, bytes(mame[name]), name)
        checked.append(name)
    same(image[0x500000:0x600000], b"\xff" * 0x100000, "unused SDRAM gap")
    result = {"status": "pass", "independent_mame_regions": checked,
              "padding": "all gaps and maincpu holes verified FF",
              "eeprom": "identical to provided asterix.nv",
              "image_sha256": hashlib.sha256(image).hexdigest()}
    if args.mame_source:
        source = args.mame_source.read_bytes()
        require(hashlib.sha256(source).hexdigest() == "878bde634f5610265273ea5d4852f7e0cad3ce15d078c4ec81090311861d45f1", "MAME snapshot hash changed")
        block = source.decode().split("ROM_START( asterix )", 1)[1].split("ROM_END", 1)[0]
        declarations = re.findall(r'ROM_LOAD(?:16_BYTE|32_WORD)?\(\s*"([^"]+)"\s*,\s*(0x[\da-f]+)\s*,\s*(0x[\da-f]+)\s*,\s*CRC\(([\da-f]+)\) SHA1\(([\da-f]+)\)', block)
        expected = {(name, offset, size, crc, sha1) for _, name, offset, size, _, crc, sha1 in SPEC}
        actual = {(name, int(offset, 16), int(size, 16), crc, sha1) for name, offset, size, crc, sha1 in declarations}
        require(actual == expected, "MAME declarations differ from independent specification")
        result["mame_snapshot_declarations"] = "pass"
    if args.mra:
        # Upstream's descriptive comment contains "--", illegal inside XML
        # comments. Ignore comments while preserving all ROM-bearing elements.
        document = re.sub(r"<!--.*?-->", "", args.mra.read_text(), flags=re.S)
        root = ET.fromstring(document)
        require(root.findtext("setname") == "asterix", "Wrong MRA set")
        rom = root.find("rom[@index='0']")
        require(rom is not None, "MRA has no index 0 ROM")
        stream = b"".join(mra_bytes(child, blobs) for child in rom)
        require(len(stream) == 0x7d0010, "Unexpected MRA stream size or layout")
        payload = stream[16:]
        # Main MRA reverses each 68000 word relative to the big-endian Pocket.
        little_main = payload[:0xc0000]
        mainbase = REGIONS["maincpu"][0]
        same(little_main[0::2], image[mainbase + 1:mainbase + 0xc0000:2], "MRA main odd lane")
        same(little_main[1::2], image[mainbase:mainbase + 0xc0000:2], "MRA main even lane")
        same(payload[0xc0000:0xd0000], blobs["068_a05.5f"], "MRA Z80")
        same(payload[0xd0000:0x2d0000], blobs["068a06.1e"], "MRA PCM")
        for name, start, length in [("tiles", 0x2d0000, 0x100000), ("sprites", 0x3d0000, 0x400000)]:
            base, _ = REGIONS[name]
            for lane in range(4):
                same(payload[start + lane:start + length:4], image[base + 3 - lane:base + length:4], f"MRA {name} lane {lane}")
        nvram = root.find("rom[@index='2']")
        require(nvram is not None, "MRA has no EEPROM default")
        same(b"".join(mra_bytes(child, blobs) for child in nvram), blobs["asterix.nv"], "MRA EEPROM")
        result["standard_mra_crosscheck"] = {"status": "pass", "sha256": hashlib.sha256(args.mra.read_bytes()).hexdigest(),
            "conversions": "main swap16; graphics reverse32; byte regions unchanged",
            "difference": "Pocket adds maincpu trailing 0x40000 FF and uses fixed region bases"}
    if args.evidence:
        evidence = json.loads(args.evidence.read_text())
        require(evidence["image"]["sha256"] == result["image_sha256"], "Identity evidence describes a different image")
        evidence["verification"] = result
        args.evidence.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile, KeyError, ET.ParseError, IndexError) as error:
        sys.exit(f"error: {error}")
