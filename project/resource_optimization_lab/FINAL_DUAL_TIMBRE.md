# 双音色终版资源验证

日期：2026-09-25  ·  分支：`codex/resource-optimization-lab`  ·  角色：A

本记录对应独立工程 `project/final_dual_timbre` 的首次 Gowin 构建。它不是把各个实验工程的资源数字相加，而是对最终 RTL、约束和顶层重新综合与布局布线后的结果。

## 终版候选结果

| 资源 | 使用 | 器件可用 | 使用率 |
|---|---:|---:|---:|
| Logic | 12,723 | 59,904 | 21.24% |
| Register | 5,459 | 60,780 | 8.98% |
| BSRAM | 80 | 118 | 67.80% |
| DSP | 57 | 118 | 48.31% |
| I/O Port | 19 | 297 | 6.40% |

50 MHz setup 和 hold 违例端点均为 0。修正 harmonic 释放步长后的构建耗时约 115.5 s，生成的本地 bitstream SHA-256 为 `74e1657ca832e75ee6b99050bca4ee15b08dd49f6ba1a79d92108307ca8313aa`。`.fs` 不提交仓库，需由同一提交在本机重建。

## 对照与取舍

- 同一 19-IO 壳层下的八路算子基线也已独立构建：harmonic-only 为 `1780 Logic / 544 Register / 32 BSRAM / 8 DSP`，pluck-only 为 `5230 Logic / 2253 Register / 16 BSRAM / 40 DSP`；两者 setup/hold 违例均为 0。它们只用于比较音色算子成本，不是可演奏产品顶层。
- `shared_sine8_complete`：`3894 Logic / 2277 Register / 1 BSRAM / 2 DSP`，逐样本对照 624 帧、0 mismatch，PnR 通过；只支持正弦，尚未板测，因此没有直接替换终版声部。
- `audio_clean_lab` 的 harmonic 候选构建：`23599 Logic / 9489 Register / 64 BSRAM / 97 DSP`；旧工程的资源数字包含完整候选外围，不能把它写成 harmonic-only 的纯音色下限。
- 终版移除 FM 和回声，固定保留 harmonic_piano 与自然衰减 pluck。每声部保留音色状态，切换音色只作用于新事件，避免切换时改写正在释放的声音。
- 终版采用可读、可板测的八声部状态结构；共享正弦调度器暂作为后续资源路线，不能在未板测情况下牺牲已认可的听感。

## 验证命令

```powershell
& ./project/final_dual_timbre/sim/run.ps1 `
  -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'
python ./project/final_dual_timbre/tools/build.py `
  --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'

# 音色算子资源对照（不是产品固件）
python ./project/resource_optimization_lab/tools/build_timbres.py `
  --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' --variant all
```

RTL testbench 覆盖：两种音色均非零输出、矩阵事件进入声部、音色按键切换、混音输出有效。PnR 只证明数字实现和时序收敛；终版尚未在板卡上下载试听，因此音质、矩阵电气连接和控制手感仍待用户板测。
