# Independent board audition, not yet performed

Use the existing Tang Mega60K + NEO Dock matrix, EC11 and PT8211 wiring.
No additional board accessories are required. All19 I/O assignments are copied
from the already user-tested five-timbre map, with the same electrical types.
This does not resolve the independent DVI Y22 pin conflict: do not attach a
display experiment with overlapping constraints without a fresh combined map.

## Safe candidates

Start `variants/piano16/piano16.gprj`; top `piano16_top`.
Then compare `variants/piano32/piano32.gprj`; top `piano32_top`.
Reopen Designer after changing projects and confirm the top name. Build outputs
are `variants/<candidate>/impl/pnr/<candidate>.fs`. SRAM download only.

| Control | Action |
|---|---|
| Matrix keys0..7 | Diatonic lower zone, defaults MIDI48/50/52/53/55/57/59/60 |
| Matrix keys8..15 | Diatonic upper zone, defaults MIDI60/62/64/65/67/69/71/72 |
| EC11 | Adjust the currently selected setting |
| S4 short press | Volume -> lower octave -> upper octave -> release -> volume |
| S2 short press and release | Toggle ordinary sustain |
| S2 hold about1second | Toggle selective sustain; releasing after a long press does not also toggle ordinary sustain |
| S1 short press | Panic with smooth master mute then bank reset; release all keys before continuing |

Initial volume18, maximum24. Release defaults3 codes/sample; larger release
index means a slower tail. Each octave zone can begin MIDI36..72.
Encoder push is not used because its wiring is unverified.

## Listening order

1. Play isolated low/middle/high notes. Compare `audio/piano8_shift0_preview.wav`
   with the safe16/32 previews. The latter are fixed1/2 and1/4 level, not
   different piano algorithms. Match perceived loudness when comparing timbre.
2. Play several non-ghosting chords with sustain off. Check released tails,
   overlapping identical notes from both zones and changing the octave while
   an old note is still held. Old note-off must still release its original token.
3. Turn ordinary sustain on, then press/release distinct strikes sequentially.
   One physical key can create several sustained independent voices. Play17
   strikes in the16 build, then33 in32: the first full-bank extra strike should
   be rejected, with the indicator briefly showing rejection. Older notes keep
   their level and are not stolen. Toggle pedal off to release them.
4. Hold notes, enable selective sustain with S2 long press, release those notes
   and play new ones. Only the captured held notes remain sustained.
5. Test ordinary and selective sustain together, then remove one followed by
   the other. Check panic recovery by pressing S1 and releasing all keys.
6. Record headphones/speaker, firmware SHA256, volume, offending pitches,
   controls and the known residual sharp/noise character. These builds do not
   claim an analogue-noise fix.

The commercial matrix without per-key diodes can ghost; its scanner suppresses
unsafe key rectangles. Capacity proof comes from independent injected-note
tests, not a claim that all16 physical keys can form every chord on this module.
The real24/25-key control board and physicalADC have not been connected here.
