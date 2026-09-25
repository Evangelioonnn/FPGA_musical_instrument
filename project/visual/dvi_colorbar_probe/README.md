# Tang Mega NEO DVI/HDMI Colorbar Probe

This is an independent display smoke test for the Tang Mega NEO 60K dock. It
does not include the audio design, matrix input, or the final system top.

## Purpose

The probe drives a fixed 1920x1080 video pattern through the board's TMDS
transmitter. Its first pin candidate is the mapping found in the repository
reference CST and in the public `ShivamKurekar/hdmi_tang60k` project:

```text
TMDS data0: J14,H14
TMDS data1: J15,H15
TMDS data2: K17,J17
TMDS clock: G15,G16
```

The NEO Rev1.4 schematic lists a different candidate. That candidate is not
mixed into this build. A stable colorbar on the user's NEO board is evidence
for the first candidate, but is not a complete schematic revision audit.

The public project is used as an RTL reference; its repository README does
not provide an official Sipeed hardware-test record. Review the source and
license before redistributing this probe.

## Build

From the repository root, use Gowin V1.9.12.03 or a compatible version:

```powershell
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/visual/dvi_colorbar_probe/build.tcl
```

The SRAM file is generated at:

```text
project/visual/dvi_colorbar_probe/impl/pnr/dvi_colorbar_probe.fs
```

The checked build was produced with Gowin V1.9.12.03 for
`GW5AT-LV60PG484AC1/I0` on 2026-09-25. Its SHA256 is:

```text
9946BE8ABE6428D5A6AD7489C8F3A336CDD29B2B26DD0AC8970EF7F5B4560CF8
```

The PnR report for this build shows 347 logic cells, 83 registers, one PLL,
no BSRAM/DSP, and 10 top-level I/O ports. The `.fs` file is a local build
artifact and is intentionally ignored by Git; rebuild it from the checked-in
sources when a repository copy is needed.

Program SRAM only. Do not write Flash for this probe.

## Board test

Power the board off before connecting the display cable. Use a normal HDMI
cable when the dock has an HDMI receptacle. If the physical receptacle is
DVI-D, use a passive DVI-D-to-HDMI cable. Select the matching monitor input.

The reset input is the board's Y12 user-button bank and is active low; leave
the button released during the test. Record the monitor model, cable type,
resolution, stable/unstable result, commit and the generated `.fs` SHA256.

The current audio `.fs` files do not drive TMDS and cannot be used for this
test. A no-signal result is not by itself proof that the candidate pin map is
wrong; check PLL lock, reset, cable and build logs before trying the separate
schematic candidate.

Record the result in `BOARD_TEST.md`. Do not change the shared audio CST for
this probe. After testing, restore the audio firmware before normal instrument
use.
