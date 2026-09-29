# Validation: independent high-polyphony piano

2026-09-28; role A; branch `codex/audio-core-v1`; baseline `de84fd3`.
Validated modules/constraints are scoped to `project/audio_polyphony_lab` and
the read-only dependencies enumerated by its generated Gowin project files.
Status: digital tests and independent16/32 board-top PnR passed; user board
audition, oscilloscope measurements and combined A+C build are still required.

## Reproducible tests

```powershell
python project/audio_polyphony_lab/sim/run.py --previews
python project/audio_polyphony_lab/tools/render.py
python project/audio_polyphony_lab/tools/build.py
python project/audio_polyphony_lab/tools/audit.py
```

`sim/poly_core_tb.v` uses independently computed sine values, MIDI frequencies,
scalar ADSR state and signed64-bit rounding expectations. It compares every
output sample and occupancy/key state at real1040-clock cadence. It checks
single-note defaults, distinct same-pitch tokens, duplicate/invalid tokens,
unknown off, full capacity, sustain tails, selective capture, ordinary/selective
overlap, event scan preemption and an intentionally shortened deadline.

| Capacity / gain shift | Frames | Maximum pipeline clocks | Peak PCM | Clipped frames |
|---|---:|---:|---:|---:|
| 8 / 0 | 5827 | 130 | 17268 | 0 |
| 16 / 1 | 5827 | 258 | 17268 | 0 |
| 32 / 2 | 5827 | 514 | 17268 | 0 |
| 16 / 0 diagnostic | 5827 | 258 | 32768 | 57 |
| 32 / 0 diagnostic | 5827 | 514 | 32768 | 274 |

The diagnostic clipping is expected and independently checked, not a zero-clip
pass. It demonstrates why a fixed safety gain is needed at the final16-bit
output. It is not caused by overflow of the signed32-bit internal mixer.

`sim/poly_equivalence_tb.v` compares4096 arbitrary phase/envelope vectors with
the actual accepted `gallery_shared_tone` renderer, PROFILE6/timbre0 and the
same4096-entry ROM. **Every pre-mix Q4 sample matches exactly.** This supplements
the independent mathematical model and does not assert that safe16/32 mode
output has the same level: fixed postmix gains are documented in SPEC.

`sim/poly_board_tb.v` drives electrical matrix rows/columns and EC11 quadrature
through the real pinned top and PT8211 clock source. Both16/32 variants pass
599-sample checks for matrix strikes, overlapping sustained restrikes, pedal,
octave change, encoder direction, smooth panic and recovery. This is a physical
input model in simulation; it is not an actual board measurement.

Preview acceleration only removes idle clocks after calculation.403 actual
PCM samples from normal1040-cycle and accelerated520-cycle32-voice schedules
match byte-for-byte. Full previews keep the actual per-sample phase/envelope
updates and output level, with0 clipping/deadline errors. Their maximum
occupied-voice count is8/16/32 as appropriate. Preview release step48 is used
for a short single-note/tail and sustained-arpeggio comparison; board defaults
remain release3. `results/simulation.json` contains the actual PASS markers.

## Focused 32-frequency spectrum

The extra focused [32-frequency spectrum test](SPECTRUM.md) now injects32
distinct held MIDI48..79 notes and detects32 distinct fundamental peaks from
32768 actual RTL PCM samples. Independent tokens/steps/nonzero envelopes are
checked alongside the FFT. Exact Fs48076.923Hz, Hann resolution1.467191Hz,
peak4107, clipping/deadline0; logical input injection, not physical board test.
The separate `results/spectrum32.json` records the source hashes and all target
results, without replacing the original regression or PnR evidence.

## Realistic standalone PnR

Gowin V1.9.12.03, GW5AT-LV60PG484AC1/I0 deviceB,50MHz SDC.
Top includes matrix scanning, event adapter, EC11, all three user buttons,
ordinary/selective sustain, volume smoothing, panic and real PT8211 pins.

| Metric | piano16 | piano32 |
|---|---:|---:|
| Logic | 4571 | 6048 |
| Register | 3627 | 3341 |
| BSRAM | 4 | 10 |
| DSP | 2 | 2 |
| I/O | 19 | 19 |
| Setup violated endpoints | 0 | 0 |
| Hold violated endpoints | 0 | 0 |
| Minimum setup slack | 1.832ns | 3.146ns |
| Fmax | 55.041MHz | 59.334MHz |

All totals fit the A+input limits29000 Logic/17000 Register/70 BSRAM/78 DSP.
The32 variant infers more voice-state BSRAM, explaining fewer registers than
the16 variant. A shared ROM and envelope multiplier replace per-voice render
hardware; four fixed harmonic weights use shifts.

FS SHA256:

```
piano16: 042d2cc6300bbd27b793ba0da14ea66f67af5c708c19933d9753f91e2bd7b072
piano32: 2e9930afeed77adf73870cab8b0ae46575bfa95343912d75ef7414e955c9b405
```

Shareable PnR records with source hashes are `results/piano16_pnr.json` and
`results/piano32_pnr.json`. Vendor reports/bitstreams remain under ignored impl.
Build scripts verify that sources do not change while each build runs. No
board programming took place. Full-level diagnostic projects have not been
built to bitstreams; their equivalent OUTPUT_SHIFT0 cores were simulated.

## Limits and next integration work

- This is one-timbre high polyphony; it does not establish simultaneous32-piano
  plus8-other-timbre capacity. Every piano voice is independent; its harmonics
  do not multiply the independent-oscillator count.
- Resource counts cannot be added to a five-timbre build and called a combined
  result. A mode selector, old-tail policy, status adapter and fresh PnR are
  needed before integrating the two cores with display/Bluetooth.
- Fixed1/2 and1/4 gains are audible on isolated notes. There is no active-count
  gain adjustment or voice stealing. Alternative final headroom policy must
  be explicit and validated rather than hidden.
- Single sound algorithm parity is digital evidence. Residual analogue noise,
  subjective timbre and key-to-output latency require actual hardware tests.
- Existing PMOD matrix pins includeY22; simultaneous DVI wiring still requires
  the central integration map. The matrix cannot prove arbitrary chords without
  per-key diodes, and neither physicalADC nor the custom control board is used.
