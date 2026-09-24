# Final dual timbre evidence

Branch: `codex/resource-optimization-lab`
Role: A
Scope: independent final integration candidate; no Flash write and no board claim.

## Verified

- `project/final_dual_timbre/sim/run.ps1` passes `FINAL_VOICE_TB_PASS` and `FINAL_ENGINE_TB_PASS`.
- The RTL testbench observes nonzero harmonic and pluck output, a matrix event entering the voice bank, and USER_BUTTON2 selecting pluck.
- Gowin 50 MHz PnR completes with `12723 Logic / 5459 Register / 80 BSRAM / 57 DSP / 19 IO`; setup and hold violated endpoints are both zero.
- Local build provenance is in `project/final_dual_timbre/impl/build_provenance.json`; the generated `.fs` is intentionally ignored by Git.

## Limits

This is not a board listening result. The final candidate still needs SRAM download and user verification of matrix wiring, the three board keys, EC11 volume/release modes, sustain, timbre switching, natural pluck decay and audio quality. The known hardware high-frequency component has not been declared fixed.
