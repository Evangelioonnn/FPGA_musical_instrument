# Shared high-polyphony piano experiment

Role A; task branch `codex/audio-core-v1`; source baseline `de84fd3`.
Owned scope is this directory. Legacy five/custom/final sources are dependencies,
and were not edited. No board programming or remote publication is performed.

This experiment extends **one** accepted timbre, Precision harmonic piano (ID0),
to 16 and 32 separate voices. It uses the same four fixed harmonic weights,
4096-entry mathematical sine and default ADSR as the accepted candidate.
Every voice has independent phase, frequency step, envelope, key state and
32-bit strike identity. Arithmetic and sine storage are shared across voices.
This is not PCM playback and does not use a CPU.

## Entry points

| Candidate | Project | Output gain before master volume |
|---|---|---|
| `piano16` | `variants/piano16/piano16.gprj` | Fixed 1/2 |
| `piano32` | `variants/piano32/piano32.gprj` | Fixed 1/4 |
| `piano16_full` | `variants/piano16_full/piano16_full.gprj` | Original full per-voice level; diagnostic |
| `piano32_full` | `variants/piano32_full/piano32_full.gprj` | Original full per-voice level; diagnostic |

The safe 16/32 candidates passed realistic 19-pin board-top PnR. Full-level
diagnostic projects are generated and digitally tested, but have not been PnR
built or recommended for board listening: simultaneous high-level voices clip
the 16-bit output. Neither safe candidate has been user board-tested yet.

## Reproduce

```powershell
python project/audio_polyphony_lab/tools/generate.py
python project/audio_polyphony_lab/sim/run.py --previews
python project/audio_polyphony_lab/tools/render.py
python project/audio_polyphony_lab/tools/build.py
python project/audio_polyphony_lab/tools/audit.py
```

Tool paths may be specified using `--modelsim` and `--gowin`.
`--extra-only` retains existing core-test results and reruns board, cadence and
legacy-renderer comparisons. `--preview-only --previews` rerenders audio only.
Simulation files and `impl` are local generated products; `results` records are
small shareable evidence. WAVs preserve real RTL output level, with no offline
normalisation. Header Fs48077 represents the exact board Fs50000000/1040.
`audit.py` checks every current build input hash, available FS hash and generated
WAV against the actual unnormalised RTL PCM. It requires the preceding build
and simulation records; a shared source change invalidates the prior result.

Read [SPEC](SPEC.md), [BOARD_TEST](BOARD_TEST.md) and [VALIDATION](VALIDATION.md)
before reusing the core or downloading a candidate.

## Focused 32-frequency evidence

The optional spectrum test uses a Python environment with existing NumPy and
an isolated ModelSim `work_spectrum` library:

```powershell
python project/audio_polyphony_lab/tools/run_spectrum.py
```

It injects32 distinct held notes MIDI48..79 and checks independent tokens,
frequency steps and nonzero envelopes, then analyses32768 actual RTL samples.
It writes only new spectrum products, leaving the original PnR records and
three previews intact. See [spectrum method and evidence](SPECTRUM.md).
