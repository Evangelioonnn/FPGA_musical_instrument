# Board Test Record

Use this file to record the first physical HDMI/DVI probe. This test is
separate from the audio final build.

## Firmware

- Build directory: `project/visual/dvi_colorbar_probe`
- Bitstream: `impl/pnr/dvi_colorbar_probe.fs`
- SHA256: `9946BE8ABE6428D5A6AD7489C8F3A336CDD29B2B26DD0AC8970EF7F5B4560CF8`
- Candidate TMDS mapping: `J14/H14`, `J15/H15`, `K17/J17`, `G15/G16`

## Procedure

1. Power the board off.
2. Connect the board HDMI-shaped receptacle to the display HDMI input with a
   normal HDMI cable. If the receptacle is physically DVI-D, use a passive
   DVI-D-to-HDMI cable instead.
3. Power the board and select the matching display input.
4. In Gowin Programmer, select SRAM programming and load the `.fs` above.
   Do not write Flash for this probe.
5. Leave the Y12 user button released. Wait for the display to lock to the
   signal and check for stable color bars.

## Result

- Date/time:
- Display make/model:
- Cable type and length:
- Display input selected:
- Picture: `stable color bars / unstable / no signal`
- Reported mode (if shown):
- Photo or screenshot path:
- Notes:

If there is no image, first recheck the selected input, cable, reset state,
and the exact `.fs` hash. A failed first candidate test is not enough to
conclude that the alternate schematic pin candidate is correct.
