# Resource optimization lab evidence

Branch: `codex/resource-optimization-lab`
Role: A
Scope: independent architecture experiment; no formal project or board Flash change.

## Verified

- `sim/run.ps1` passes the ROM sharing probe, pruned sine lower-bound probe, shared multiplier probe, shared-bank smoke test, and `resource_shared_sine_compare_tb`.
- The shared eight-voice default-sine candidate matches the sine-only production reference for 624 output frames under the same accepted event sequence: `0 mismatch`.
- Gowin 50 MHz PnR completes with `3894 Logic / 2277 Register / 1 BSRAM / 2 DSP / 19 IO`, setup/hold violated endpoints `0/0`, and worst reported setup/hold slack `6.547/0.247 ns`.

## Limits

This is RTL and implementation evidence only. The candidate accepts timbre 0, has not been loaded onto the Tang Mega 60K, and has no FM/pluck equivalence or three-timbre resource result. The generated `impl/` products and `.fs` are local build outputs and are not part of the repository handoff.

## Reproduce

```powershell
& ./project/resource_optimization_lab/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'
python project/resource_optimization_lab/tools/build_shared_sine.py --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'
```
