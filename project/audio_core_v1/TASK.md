# Audio core V1 task

Date: 2026-09-28. Owner: A. Branch: `codex/audio-core-v1`.
Source baseline: `de84fd3`; accepted sound selection is documented in
`evidence/audio_selection_2026-09-28/BOARD_LISTENING.md`.

## Scope

Work directories: `project/audio_core_v1`, `project/audio_parameter_lab`,
`project/audio_polyphony_lab`, `project/audio_fx_lab`, and dated evidence/current
handoff documentation. Existing board-tested projects remain references.

Deliver a playable eight-voice candidate with stable preset IDs 0/2/3/4/5,
one authoritative parameter state, simulated ADC/host inputs, real observations,
and documented interfaces. Independently pursue shared-compute 16/32-voice piano
and a bypassable short-room effect. Physical SPI ADC, new input PCB, measured
analog latency and display/Bluetooth integration remain separate acceptance.

## Gates

1. Record default sound and control behavior before edits.
2. Define units, transaction timing, defaults, rejected commands and ownership.
3. Test against independent numerical/protocol expectations and old defaults.
4. Verify each selected board top by synthesis, PnR and 50 MHz timing.
5. Preserve C's allocation. A+input limits are 29000 Logic, 17000 Register,
   70 BSRAM and 78 DSP. Whole-system timing requires a later combined build.
6. Render actual RTL PCM; board audition is a later user acceptance step.

## Progress

- [x] Initial files, previous resource results and tool scripts reviewed.
- [x] Five-preset mapping and single-timbre polyphony scope confirmed.
- [x] Unified parameter service and current-board adapter.
- [x] Voice/ADSR integration and 9000-frame default bank equivalence.
- [x] State/PCM interface and 5678-frame config/ADC/core stress checks.
- [x] Shared piano 16/32 experiments, independent model and 50MHz PnR.
- [x] Short-room/vibrato experiment, bounded arithmetic and core integration.
- [x] Final main PnR: 24151 Logic / 10918 Register / 42 BSRAM / 72.5 DSP.
- [x] Non-identical stereo serial regression: 367 PCM frames / 732 serial words.
- [x] Previews and evidence collection; each scene's PASS count, stereo PCM range/hash and assembled WAV data are cross-checked.
- [x] Repository checks and local commit; handoff is documented for user board audition and B/C integration.

No physical programming or external teammate messaging is part of this task.
