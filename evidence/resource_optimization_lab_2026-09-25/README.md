# Resource optimization lab evidence

Branch: `codex/resource-optimization-lab`
Role: A
Scope: independent architecture experiment; no formal project or board Flash change.

## Verified

- `sim/run.ps1` passes the ROM sharing probe, pruned sine lower-bound probe, shared multiplier probe, shared-bank smoke test, and `resource_shared_sine_compare_tb`.
- The shared eight-voice default-sine candidate matches the sine-only production reference for 624 output frames under the same accepted event sequence: `0 mismatch`.
- Gowin 50 MHz PnR completes with `3894 Logic / 2277 Register / 1 BSRAM / 2 DSP / 19 IO`, setup/hold violated endpoints `0/0`, and worst reported setup/hold slack `6.547/0.247 ns`.
- The same 19-IO shell was used for operator-only eight-voice baselines: harmonic `1780 Logic / 544 Register / 32 BSRAM / 8 DSP` and pluck `5230 Logic / 2253 Register / 16 BSRAM / 40 DSP`; both completed 50 MHz PnR with zero setup/hold violated endpoints. These are cost probes, not product top levels.
- The independent final dual-timbre candidate was then rebuilt from its own RTL and constraints: `12563 Logic / 5400 Register / 80 BSRAM / 57 DSP / 19 IO`, setup/hold violated endpoints `0/0`. Its detailed scope is recorded separately in `evidence/final_dual_timbre_2026-09-25/`.

## Limits

This is RTL and implementation evidence only. The shared candidate accepts timbre 0 and has not been loaded onto the Tang Mega 60K; it has no FM/pluck equivalence. The final dual-timbre candidate is a separate integration candidate and also has not been board tested. The generated `impl/` products and `.fs` are local build outputs and are not part of the repository handoff.

## Reproduce

```powershell
& ./project/resource_optimization_lab/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'
python project/resource_optimization_lab/tools/build_shared_sine.py --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'
```
