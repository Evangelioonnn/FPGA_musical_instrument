# Board audition candidate

This is a separate six-option audition build. The first five preset sounds and
controls retain the five-timbre candidate behavior; pressing S1 once more
selects preset 5, the editable four-harmonic renderer at its accepted piano
default. In preset 5 only, EC11 temporarily emulates the five fader channels.
The board still does not read a physical SPI ADC.

Build using `python project/custom_harmonic_lab/tools/build_custom.py`. Only
load `project/custom_harmonic_lab/impl/pnr/custom_harmonic.fs` if the generated
`impl/build_provenance.json` records `timing_pass: true` and `budget_pass: true`.
Use the previously verified SRAM programming procedure. Confirm Top Module/Entity is
`custom_harmonic_top`; this candidate has 19 I/O pins using its own CST/SDC.
Keep `final_dual_timbre` as the known-good physical rollback.

Use the existing 4x4 matrix, EC11 and audio wiring documented by
`project/input/matrix_playable/WIRING.md`. S1 cycles in this order: Precision
harmonic piano, original pluck, Warm pluck, Metallic bell, Drive lead, editable
harmonic piano default. In preset 5, S4 short selects CH0, CH1, CH2, CH3 or
CH4; each EC11 detent changes the selected simulated 12-bit fader by 64 codes.
S1 exits preset 5. Compare presets 0 and 5 at the same volume using the same
low/middle/high notes and chords; the digital test checks PCM equality at the
default coefficients. Sweep one channel at a time while holding a note, then
try a chord and all five channel endpoints. The input is an EC11 surrogate,
not the final fader hardware; this audition says nothing about the analog
noise issue.

Do not connect an ADC until its part, voltage, SPI mode, pinout and J13 signal
assignment have been checked against B's electrical design. The current build
has no ADC wires assigned.
