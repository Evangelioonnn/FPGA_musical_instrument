# Editable four-harmonic timbre lab

Standalone experiment for a user-editable additive timbre. CH0 is post-mix
master volume; CH1..CH4 set the fundamental and its 2x, 3x and 4x harmonics.
The DSP side uses the existing eight-voice bank and shares the harmonic
multiply datapath across four partials. The board candidate temporarily maps
the existing EC11 to five simulated 12-bit fader values; no physical ADC is
required for this phase.

The documented default is intended to reproduce the accepted Precision
harmonic piano. This is a new digital candidate, not yet board-listened or
integrated into `five_timbre_core`. The SPI ADC and its J13 pin assignment are
not connected or frozen here.

The parameter path has six passing ModelSim benches, including exhaustive ADC
mapping, bounded live crossfades and an eight-voice peak test. See
[VALIDATION.md](VALIDATION.md) for the current whole-candidate PnR gate and
evidence boundary. See [SPEC.md](SPEC.md) for coefficient units, normalization and update timing,
[BOARD_TEST.md](BOARD_TEST.md) for the candidate controls, and
[ADC_INTEGRATION.md](ADC_INTEGRATION.md) for the future SPI handoff, and
[VALIDATION.md](VALIDATION.md) for test commands and current evidence.
