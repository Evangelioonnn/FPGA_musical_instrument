# Editable harmonic validation

Date: 2026-09-28. Owner: A. Branch: `codex/editable-harmonic`.

This is a digital design candidate. It is not yet connected to a physical ADC,
has not been auditioned on the board, and is not integrated with display or
Bluetooth. `final_dual_timbre` remains the physical rollback. Four shared-phase
harmonics are a spectral shape per voice, not 32 independent oscillators.

## RTL checks

Run from the repository root:

```powershell
python project/custom_harmonic_lab/sim/run_custom.py
```

The six ModelSim benches currently pass and cover:

- All 4096 ADC input codes for rounded Q8 coefficients and monotonic Q0.16
  volume mapping; accepted default coefficients and invalid-scan retention.
- Full-slider normalization to `[92,92,92,92]`, atomic snapshot rejection and
  sticky overrun reporting while normalization is busy.
- Live-vector crossfades, including two legal endpoint vectors whose naive
  independent slew would exceed the cap; every intermediate coefficient sum
  stays at or below 368.
- Default four-harmonic samples against `gallery_shared_tone` over 32 phase
  and envelope frames, per-harmonic parameter changes, eight-voice scan timing,
  and normalized peak bounds.
- The new six-preset bank accepts preset 5; its default piano PCM equals
  preset 0 across 64 bank output frames. Eight active custom voices render 512
  frames without clip/deadline errors, and the peak output is checked against
  the normalized 16-bit mix bound.

The current passing RTL results are recorded here after the final PnR run.
Rendered audio is not evidence of physical sound quality.

## Physical/resource limits

The eight-voice renderer scans one shared four-harmonic sine datapath and
reuses its coefficient multiplier. The standalone tone bench completes within
220 clocks; the full bank allows 176 clocks for the renderer and mixer capture,
inside the 1040-clock sample interval. The expected normalized same-phase
eight-voice upper bound is about +/-23552 PCM counts at full CH0 volume; the
RTL tests assert a conservative +/-23560 limit.

The previous pre-fix dynamic-normalizer build is a negative result and must not
be programmed: its combinational ADC-to-coefficient path produced 1,178 setup
violations, -14.255 ns reported worst slack and 29.193 MHz Fmax. That result
motivated the shared sequential divider. The current RTL and six-test suite
have been updated; the new whole-candidate PnR is the acceptance gate below.

The PnR report is generated from `custom_harmonic.gprj` and records
Logic/Register/BSRAM/DSP/IO, setup/hold violations, minimum setup slack, Fmax
and bitstream SHA-256. The A+input budget is 29,000 Logic, 17,000 Register,
70 BSRAM, 78 DSP and 19 IO. This is the audio/control candidate only, not a
combined C/A display-and-Bluetooth PnR. No `.fs` is for board use unless the
new report has zero setup/hold violations, Fmax at least 50 MHz, and all
candidate resource limits pass.

The final dynamic-parameter PnR for this branch passed: 21,330 Logic, 9,755
Register, 38 BSRAM, 70 DSP and 19 IO; setup/hold violations were 0/0, minimum
setup slack was 3.967 ns and Fmax was 62.369 MHz. The generated bitstream
SHA-256 was
`eda2ac24e4975691e621f08f7edf4d33610e8e3c45a454d0fd7668d8b6593b59`.
These are standalone audio/control-candidate results. The `.fs` is not yet
user-board-tested, the physical SPI ADC is absent, and the margin will need to
be rechecked after C's display/Bluetooth logic is integrated.
