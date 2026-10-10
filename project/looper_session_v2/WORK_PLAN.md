# 2026-10-10 execution plan

Role A, existing shared branch recorded in results/BASELINE.json. No board/display files modified.

1. Freeze refinement source/FS baseline and feedback.
2. Re-map pads and tune kick/four toms/closed-open hats/brighter longer crashes; snare unchanged; remove requested voices. Keep clap/rim as optional pending user decision.
3. Independent fixed-point drum oracle: all pads/velocities, pitch, amplitude, choke/flush/full slots, eight-voice sum and1040-clock deadline.
4. Define8-bit action API, explicit range/locked/busy/full/empty replies, local control arbitration, audio ACK ownership; implement.
5. LU1 narrow screen-status stream plus unpacker/mock; same-reset async crossing, whole-packet commit, backpressure/drop/session. Full LR1 optional.
6. Existing regressions plus true command->platform->store->audio and CDC tests. PCM comparison for unchanged melody/snare/default approved tom timbre.
7. One playable board candidate, frozen reference WAVs, final50MHz PnR. Probe logical-link resource with audited ports only if useful; no display integration qualification.
8. Publish local C handoff, source manifests, acceptance pad map/guide and precise limitations.

Acceptance: five melody voices behave as accepted; drums match intended mappings with no overflow; commands return held tagged replies, rejected commands do not mutate state; recording/undo/clear/gain isolate tracks; LU1 never tears; FS requires routed PnR and zero setup/hold violations. Pending real display/ADC/control board/analog tests remain explicit.
