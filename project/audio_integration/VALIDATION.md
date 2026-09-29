# Audio Integration Validation · 2026-09-29

This document records digital evidence for the shared V2 audio interface. The machine-readable resource result is [pnr_baseline_50.json](results/pnr_baseline_50.json); it contains source fingerprints, build directory, resource counts, timing checks, and the generated audit image hash.

## Complete Core and Transport

ModelSim passed all three isolated bridge tests and the complete V2-core link test. The full test runs the real 50 MHz audio core at its 1040-clock sample cadence and checks output PCM against the actual pre-DAC samples, all state words and compact UI fields, and canonical command ACKs.

| Regression | Result |
|---|---|
| Snapshot bridge | 5 complete records, 238 accepted words, 97 stalled cycles; 2 publications dropped while owned, 1 interrupted copy; reset during copy/partial record |
| PCM bridge | 258 exact frames delivered, 10 full-FIFO drops, 1 busy-serializer drop, 7 gaps, 2 sessions, 731 stalled cycles; pointer wrap and queued/serializing reset |
| Command bridge | 6 replies, 7 service ACKs, 1 local ACK filtered, 2 NACKs, 26 host stalls, 38 reply stalls; pending/reply reset and unexpected ACK diagnostic |
| Complete core link | Recorded `CORE_TRANSPORT_TB_PASS`: 4300 source PCM frames, 4262 received, 4295 nonzero source frames, 4 core snapshots, 3 complete records/views, 7 commands, 37 PCM drops, 1 state drop; audio continued during observer stalls |

The complete-core PASS and its source fingerprint are retained in [core_transport_validation.json](results/core_transport_validation.json). During the current runner-isolation update, a fresh-library repeat reached the simulation command but stopped producing output; that attempt was terminated and is **not** counted as a new pass. Comparing its recorded inputs with the current tree found all RTL, testbench, manifest and API sources identical; only the Python runner and ROM-check wrapper changed to use unique temporary libraries. The ROM equivalence test itself passed in the fresh library, and all three bridges passed with the updated runner. The recorded full-core result remains the evidence for current RTL; a fresh full-core confirmation should be repeated in another ModelSim runtime if that simulator stall recurs.

Reproduce the package export and consumer checks from the repository root:

```powershell
python project/audio_integration/tools/package_check.py --static-only
python project/audio_integration/tools/package_check.py --modelsim-bin <ModelSim-bin-directory>
python project/audio_integration/sim/run_transport.py
python project/audio_integration/sim/run_transport.py --test core_transport_tb
```

The package checker exports to a fresh temporary directory, compiles/elaborates the four manifest profiles, exercises compact-state atomic commit/gap/error handling and the observer mock, and checks source fingerprints during the run. `--static-only` checks the manifests and module inventory without ModelSim.

## Retained-Interface PnR Audit

The latest Gowin run used the default V2 bank, a 50 MHz audio clock, and a 50 MHz observer/client clock. It completed synthesis, placement, routing, and timing analysis with no setup or hold violating endpoints and no unmatched constraint warnings.

| Resource/timing | Result |
|---|---:|
| Logic | 31,075 / 59,904 |
| Register | 15,790 / 60,780 |
| BSRAM | 64 / 118 |
| DSP | 24.5 / 118 |
| Audit top IO | 32 / 297 |
| Minimum setup slack | 0.076 ns |
| First-clock Fmax | 50.191 MHz |
| Setup / hold violating endpoints | 0 / 0 |
| Unmatched constraint warnings | 0 |

The audit top retains the V2 core, 25-key logical mapping, existing matrix scanner/EC11/DAC/status LED, and all three bridges. It drives ADC and host requests internally to retain those logic cones without inventing dozens of physical pins. The 9 additional key inputs are logical test inputs, not an approved board pinout. The top is **not downloadable**. Its 50 MHz observer domain is not C's pixel-clock/display implementation.

This is a real PnR result for the audit harness, not an end-product board top. It does not include a physical SPI ADC, B's final control PCB, C's display renderer/FFT/UART/Bluetooth, or a board test. The small 0.076 ns positive setup margin is fragile; C integration and any top-level/pin/clock changes require a fresh whole-system PnR and timing review. See the updated [team resource budget](../../docs/team/RESOURCE_BUDGET_V1.md) for allocation accounting.

Rebuild with Gowin Designer available at its default path, or pass the local executable explicitly:

```powershell
python project/audio_integration/tools/build_integration.py --gowin <path-to-gw_sh.exe>
```

Each invocation creates a fresh directory under `tmp/audio_integration_audit/` so a stale Gowin `.gprj.user` file cannot restore prior pin/flow settings. The generated audit project and `.fs` are temporary build outputs, not board firmware.

## Optimization Candidate Decision

`optimized/audio_v2_bank_packed.v` is **rejected as the default or an integration override**. Reproduce the negative check with `python tools/optimization_sim.py --test packed_equivalence_tb`; the expected assertion is a nonzero simulator exit at frame 1274 on Warm pluck, candidate PCM 133 versus reference 164. The additional RAM read delays the shared mix point by about 96 clocks, so it observes the live pluck sample at a different point in the same audio frame. Harmonic phase/envelope and slot occupancy match, but PCM equivalence does not; no PnR was run for this candidate.

The default manifest remains `project/audio_core_v2/src/audio_v2_bank_stream.v`. The explicit `--bank` escape hatch only describes import/build mechanics; a candidate must pass exact functional equivalence, sample deadline, and PnR before adoption.
