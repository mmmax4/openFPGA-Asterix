# Build the corresponding source

Install Quartus Prime Lite 21.1.1 with Cyclone V support, Bash and Python 3.
Target: 5CEBA4F23C8. The snapshot includes all 173 exact recorded source/configuration
inputs, PLL descriptions/wrappers, CPU microcode and preserved notices.
No game ROM is needed to synthesize the FPGA circuit.

```sh
bash scripts/build.sh compile
```

Set QUARTUS_BIN to the installed Quartus bin directory when necessary. Map,
fitter, assembler and TimeQuest run sequentially. Source/report hashes are
captured per stage in build/. Run one Quartus process at a time.

Raw output: `src/projects/output_files/asterix_pocket.rbf`. Reverse the eight
bits in each byte, without reversing byte order, for Pocket `astdev.rbf_r`:

```sh
python3 scripts/reverse_rbf.py src/projects/output_files/asterix_pocket.rbf astdev.rbf_r
```

Check newly generated timing/warnings at all corners; build exit alone does not
qualify a new circuit. The distributed v014 circuit's hashes/source identities
are in docs/PROVENANCE.json. Proprietary Quartus libraries/tools are not vendored.

ROM assembly needs only the Python standard library; see README. Private-proof
runners/fixtures and full machine captures are intentionally excluded. No runnable
standalone full validation suite or fresh v014 1,400-frame replay is claimed in
this public snapshot; docs/VALIDATION.md describes the actual recorded evidence.
