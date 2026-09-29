# Audio core V2 task

Date: 2026-09-29. Owner: A. Branch: codex/audio-core-v2.
Baseline: 615cb94 (audio_core_v1, independent piano16/piano32).

## Authorized scope

Integrate 32 piano voices, expand other accepted timbres within the existing
A+input budget, preserve voice identity and old tails, publish coherent state,
measure digital latency and render real RTL PCM. Existing board wiring remains
the starting point. Physical ADC and display/Bluetooth integration are separate.

Budget: 29000 Logic / 17000 Register / 70 BSRAM / 78 DSP, including current
input and room effect. Preserve C's complete allocation and input headroom.
Global active-voice limit: 32. Stable presets: 0/2/3/4/5.

## Gates

- [x] User accepted V1 main and independent 16/32 piano on board.
- [x] Define split pools, fixed gains, state format and timing.
- [x] Verify preserved tones against accepted RTL and independent arithmetic.
- [x] Verify full capacity, mixed tails, note-off, sustain, custom and faults.
- [x] Finish 50MHz board PnR and full-interface capacity audit.
- [x] Explore higher Warm pluck capacity without exceeding budget (12 selected;16 rejected).
- [x] Measure digital latency and record its physical limits.
- [x] Produce RTL WAV, board-test guide and B/C interface handoff.
- [x] Repository checks and local task commit (see branch history).

Optional Lead legato requires an independent playable experiment after the
mandatory gates, and must not replace the accepted polyphonic mode silently.
