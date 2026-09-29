# Audio parameter service experiment

Owner A, task branch `codex/audio-core-v1`.
This directory owns only configuration arbitration and physical-fader pickup.
It does not synthesize sound, normalize harmonic coefficients, smooth PCM gain,
implement SPI, or assign a physical ADC pin.

`src/audio_parameter_service.v` is a 50 MHz synchronous module with active-high
reset and frame-boundary publication. The stable preset IDs are 0/2/3/4/5;
legacy ID 1 is rejected. The default master gain is 8249 Q16, reproducing the
previous index-18 gain after its legacy 65535/65536 custom-volume stage.

Read [SPEC.md](SPEC.md) before integration. Run the focused regression with:

```powershell
python project/audio_parameter_lab/sim/run_parameters.py
```

The default ModelSim path is `E:/QuartusII/modelsim_ase/win32aloem`; use
`--modelsim` for another installation. Both focused tests pass; coverage and
limitations are in [VALIDATION.md](VALIDATION.md). The script saves actual PASS
or FAIL status, test markers and source hashes in
[results/parameters_validation.json](results/parameters_validation.json), or
another path specified by `--output`. ModelSim products remain ignored.

This module must be included in the audio-core whole-design PnR before its
resource/timing can be claimed. Physical ADC and analog audio are unverified.
