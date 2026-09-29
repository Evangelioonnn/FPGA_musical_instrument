# Final dual timbre evidence

Branch: `codex/resource-optimization-lab`
Role: A
Scope: independent audio integration candidate; digital evidence below, followed by later user board feedback. No Flash write.

## Verified

- `project/final_dual_timbre/sim/run.ps1` passes `FINAL_VOICE_TB_PASS` and `FINAL_ENGINE_TB_PASS`.
- The RTL testbench observes nonzero harmonic and pluck output, a matrix event entering the voice bank, and USER_BUTTON2 selecting pluck.
- Gowin 50 MHz PnR completes with `12723 Logic / 5459 Register / 80 BSRAM / 57 DSP / 19 IO`; setup and hold violated endpoints are both zero.
- Local build provenance is in `project/final_dual_timbre/impl/build_provenance.json`; the generated `.fs` is intentionally ignored by Git.

## Limits

The user subsequently confirmed SRAM listening and reported that the implemented effects worked well, accepting this as the first complete audio demonstration. This supplements the original digital evidence; no new waveform capture, analog latency measurement or combined audio/video test was supplied. The high-frequency component's root cause has not been declared fixed. See [current status](../../docs/project/STATUS.md) and [team budget](../../docs/team/RESOURCE_BUDGET_V1.md) for the next integration stage.
