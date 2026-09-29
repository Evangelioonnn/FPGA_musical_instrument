# Short-room effect and shared Lead vibrato

This independent experiment supplies reusable RTL to A's unified audio core.
It has no ADC, Bluetooth or display implementation and has not been board auditioned.
The 19-port `fx_resource_top` is a resource/timing probe, not a playable product top.
Root branch owns integration; this directory has no changes to legacy audio sources.

## Build and verification

```powershell
python project/audio_fx_lab/sim/run_fx.py
python project/audio_fx_lab/tools/build_fx.py
```

ModelSim defaults to `E:/QuartusII/modelsim_ase/win32aloem`; pass `--modelsim`
to use another installation. Simulation checks measured RTL outputs against a
separate integer recurrence and creates WAVs from those outputs. The input
reference is a synthetic decaying harmonic melody, not prerecorded FPGA playback.
Nominal sample rate is `50_000_000/1040 = 48076.9230769 Hz`; WAV header rounds to48077.

Generated simulation libraries, transcripts, vectors, waveforms and `impl` are
local artifacts. Commit RTL, testbenches, scripts, constraints and result summaries.

For a shorter stress run, use `--frame-clocks 40`. This exercises the same
sample recurrence at faster-than-nominal input spacing; use the default1040
for the nominal clock schedule. Both retain exactly24 clocks of measured latency.

Latest standalone PnR:788 Logic /487 Register /4 BSRAM /1.5 DSP /19 IO;
setup/hold violations0/0, minimum setup slack8.235ns, Fmax84.996MHz. Actual
audio-core integration must be implemented separately.

See [SPEC](SPEC.md) for arithmetic and interface contracts and
[VALIDATION](VALIDATION.md) for measured results and remaining physical checks.
