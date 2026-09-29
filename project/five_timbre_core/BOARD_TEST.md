# Five-preset board audition

Connect the same 4x4 matrix, EC11 and audio output as the prior gallery test;
see [matrix wiring](../input/matrix_playable/WIRING.md). Start with
`variants/five_00_reference/five_00_reference.gprj` and its matching
`variants/five_00_reference/impl/pnr/five_00_reference.fs`. Compare 01 and 02
only after recording the 00 sound at the same volume and output device. Open
exactly the chosen variant's `.gprj`, check that Top Module/Entity matches its
folder name, then load that folder's `.fs` using the already verified SRAM
programming procedure. The generated files exist locally after a passing
build; `impl/build_provenance.json` records the source and bitstream hashes.
Do not use a build whose setup or hold violations are nonzero. These generated
`.fs` files are ignored by Git and must be rebuilt on a different computer.

All variants start with piano at volume index 18, ordinary/selective sustain
off, both zone bases C3/C4, default release, glide off, bend centered and lead
attack index 2. S1 cycles the five presets in this exact order:

| S1 presses | Preset | RGB indicator |
|---:|---|---|
| 0 | Precision harmonic piano | Blue |
| 1 | Original pluck | Amber |
| 2 | Warm pluck | Green |
| 3 | Metallic bell | Magenta |
| 4 | Drive lead | Red |

S2 short toggles ordinary sustain. S2 held for about one second toggles
selective sustain and captures keys held at that moment; long release does not
also toggle ordinary sustain. S4 short cycles encoder modes: volume, left
octave, right octave, release, glide, bend, lead attack. S4 held about one
second panics. EC11 press is unused; the module's C contact stays unconnected.

First hold the same low/middle/high matrix pitches on all five presets. Compare
original versus warm pluck at the same board and amplifier setting. For piano
and Drive lead, compare C3/C4/C5 between `00`, `01` and `02` at identical
volume index and output device. Check chords at moderate level, then increase
volume carefully to the previously problematic range. Record bass/treble
loudness, pitched sharp noise, new-onset noise and natural tail separately.

For Drive lead, hold one key and rotate bend both directions, then center or
leave the bend mode. Hold one lead note and press another with glide on, then
try quick upward/downward sequences. Adjust attack in its own mode; the change
affects new strikes. Test ordinary sustain with piano, then selective sustain:
hold one piano key, activate selective sustain, release it, press and release
a second key, and check only the first remains held. Two plucks and bell should
keep their natural tails regardless of either sustain switch.

The current matrix has no per-key diodes. Three corners of a rectangle invoke
ghost protection, so use same-row combinations for reliable polyphony checks.
The physical input has 16 keys; the full 25-note chromatic adapter is verified
digitally for B's future controller, not demonstrated by this matrix.
