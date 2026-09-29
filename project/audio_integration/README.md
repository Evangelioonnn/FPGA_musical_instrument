# Audio Integration Pack V1

This is A's shared handoff for connecting the current `audio_core_v2` synthesizer to C's display/Bluetooth work. It contains no board top-level, pin assignments, or download image. Keep using [audio_core_v2](../audio_core_v2/README.md) and its 19-IO project when you need the known board-playable audio fallback.

## Start here

1. Read the [audio import rules](../../docs/interfaces/AUDIO_IMPORT_V1.md), the [transport contract](../../docs/interfaces/AUDIO_TRANSPORT_V1.md), and [audio V2 field definitions](../../docs/interfaces/AUDIO_CORE_V2.md).
2. Run `python project/audio_integration/tools/package_check.py --static-only` from the repository root. With ModelSim installed, omit `--static-only` to run clean export/elaboration and consumer tests.
3. Use `project/audio_integration/tools/import_audio.tcl` or the source manifest to add exactly one audio bank to an existing Designer project. Do not import the audit top as a board project.
4. Build C's renderer and protocol against `audio_observer_mock` first. Then connect `audio_state_view`, `audio_snapshot_bridge`, `audio_pcm_bridge`, and `audio_command_bridge` through `audio_integration_example`.

## Contents

| Path | Purpose |
|---|---|
| `tools/source_manifest.json` | Canonical source lists for core, bridge, integration, and consumer profiles |
| `tools/import_audio.tcl` | Portable Tcl importer for Gowin Designer |
| `include/audio_api_v2.vh` | Shared preset IDs, address, units, and state-record constants |
| `rtl/` | Common reset, atomic state snapshot, full-rate PCM, and command/ACK CDC bridges |
| `examples/audio_integration_example.v` | Synthesizable wiring example for the real V2 core and bridges |
| `examples/audio_state_view.v` | Optional compact, atomic UI state decoder |
| `examples/audio_observer_mock.v` | Predictable synthetic PCM/state for independent observer development |
| `sim/` | Independent bridge and complete-core transport regressions |
| `audit/` | Non-downloadable retained-interface timing/resource harness |
| `optimized/` | Rejected packed-bank experiment retained with its failing equivalence evidence |

## Resource and validation boundary

Read [VALIDATION](VALIDATION.md) and the [updated team budget](../../docs/team/RESOURCE_BUDGET_V1.md) for exact results and limitations. The core transport bench uses the real 1040-audio-clock sample cadence and confirms that stalled observers drop/count data without stalling synthesis. The resource audit drives ADC and host requests internally; it is useful for estimating retained audio/input/transport logic, but it is not the real SPI ADC, C's UI/UART/Bluetooth, or a downloadable board top. Its synthetic extra keys are not physical pin assignments.

No result here establishes analog SNR, end-to-end acoustic latency, physical ADC operation, or integrated display/Bluetooth acceptance. The packed-bank alternative changed Warm pluck PCM and is not an approved optimization. The default source manifest therefore continues to select the unchanged V2 streaming bank.

Run the three focused CDC regressions with:

```powershell
python project/audio_integration/sim/run_transport.py
```

Run complete-core transport coverage with:

```powershell
python project/audio_integration/sim/run_transport.py --test core_transport_tb
```
