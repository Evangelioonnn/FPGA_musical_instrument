# Parameter-service validation

Role A; branch `codex/audio-core-v1`. The allowed implementation scope is
`project/audio_parameter_lab`; the integrated audio top and final PnR belong
to the main audio-core task. This directory does not reassign board pins.

## Reproduction

```powershell
python project/audio_parameter_lab/sim/run_parameters.py
```

ModelSim Altera 10.1d, default binary path
`E:/QuartusII/modelsim_ase/win32aloem`. Compilation uses `-vlog01compat`.
The regression has two PASS markers and writes an auditable
[JSON result with source hashes](results/parameters_validation.json).
No extra argument is needed for the complete run.

| Test | Result | Independent expectation and coverage |
|---|---|---|
| `audio_parameter_tb` | PASS | Both continuously valid config sources alternate; accepted payload survives delayed sample enable and live-bus changes; invalid IDs/ranges leave targets and revision unchanged; signed relative volume saturates at 0/65536; ADSR writes apply and enable override; panic is one clock; restore publishes defaults; independent fader channels acquire only at tolerance/crossing; host writes re-arm; zero mutes before pickup; held harmonic snapshot is stable; ADC overrun rejects the entire second scan |
| `audio_fader_range_tb` | PASS | All 4096 ADC codes compared with independent integer mapping `code*16 + code/256`, special full-scale 65536; monotonic increments bounded by 17; exact mute/unity endpoints; master-only scans make progress while harmonic consumer is permanently blocked; harmonic bundle remains unchanged |

The first bench advances `sample_ce` every 32 clocks and deliberately pauses
it to expose commit behavior. The mapping bench asserts `sample_ce` each
clock to isolate scalar conversion from audio scheduling. These focused tests
do not establish the integrated 1040-clock audio deadline; that needs the
full audio-core regression and implementation.

No additional PnR was run for this stand-alone service. Capacity and 50 MHz
setup/hold must be reported from the complete audio design containing it.
Physical SPI ADC, actual fader calibration/noise, J13 wiring, analog latency,
audio quality and display/Bluetooth hardware integration remain unverified.

## Integration details

- The default master target 8249 reproduces the previous 8250 table gain
  followed by the legacy 65535/65536 stage. The consumer owns PCM gain slew.
- The four raw harmonic targets feed `custom_harmonic_params` through held
  snapshot ports. The consumer forces that normalizer's CH0 to 4095 and ignores
  its volume output. Existing sum normalization/smoothing is reused.
- A coherent ADC scan changing harmonics waits for downstream normalization
  readiness. That readiness must be bounded; the current normalizer's maximum
  sequential computation is below one audio frame.
- Config replies acknowledge target publication. The complete audio design
  must actually consume every supported target; unused controls cannot be
  advertised as implemented just because this service accepts their values.
- Physical CH0 exact zero is a safety mute and can supersede host unmute on
  the next committed scan. Show pickup status and actual parameter targets
  to a host/display rather than assuming the physical position is active.
