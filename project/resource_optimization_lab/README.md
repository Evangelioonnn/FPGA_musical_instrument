# resource_optimization_lab：资源优化验证区

这是一个独立的资源优化实验工程，不替换正式 `project/input/matrix_playable`。目标是在保持 50 MHz 音频帧率、八声部基本演奏行为和原正弦音色可接受性的前提下，找到可以迁移到最终工程的资源路径。

## 当前基线

`matrix_playable` 的最近一次可复现构建为：23659 Logic、9684 Register、40 BSRAM、97 DSP、19 IO；50 MHz setup/hold 最差余量为 0.251/0.048 ns。DSP 已达到 82.2%，所以本实验优先验证声部间共享，而不是只做代码整理。

## 候选

| 变体 | 做法 | 目的 | 结论边界 |
|---|---|---|---|
| `pruned_sine8` | 每个声部只保留原正弦 DDS+ADSR，移除 FM/拨弦电路 | 量出“删除未选音色”能节省多少 | 可作为资源下限和诊断对照；不支持三音色，不能直接作为最终固件 |
| `shared_sine8` | 八声部共用一套正弦 ROM、乘法和顺序调度，每个声部保留独立相位/包络 | 验证跨声部时分复用能否保持 48 kHz 帧率 | 当前只覆盖正弦音色；需先通过数字音频和 PnR，再扩展到共享 FM/拨弦 |
| `shared_sine8_complete` | 完整八声部默认正弦候选，共用同步 ROM 和波形×包络乘法路径 | 验证可迁移的正弦核心 | 已通过逐样本事件对照（624 帧，0 mismatch）与 50 MHz PnR；只接受 timbre 0，尚未板测 |
| `baseline_reference` | 使用现有 `matrix_playable` 顶层和源码指纹 | 资源/时序对照 | 不在本工程重新生成正式 bitstream |

每个变体都必须有独立仿真、资源报告和 setup/hold 检查。仿真通过不能替代板测；本实验不写 Flash、不上传 `.fs`。

## 官方 IP 评估

本机 Gowin V1.9.12.03.03 的 IP 目录确认存在 `DDS_II`、`RAM_pROM`、`RAM_SDPB`、`DSP_MULT`、`FIFO_SC`、`FFT` 等。当前判断：

- `RAM_pROM`、`DSP_MULT` 已由现有 HDL 推断出 BSRAM/DSP，显式 IP 只有在端口时序和映射报告更好时才值得替换。
- `DDS_II` 适合后续“共享 DDS 调度器”实验，但必须核对 GW5AT-60B、通道时分复用、相位延迟和仿真模型；本轮先用可读 RTL 建立资源/音频基准。
- `FFT` 只属于 C 的显示支线，不能为了资源实验把 FFT 接入音频主路径；完整采样流、窗函数和跨域预算尚未冻结。
- 软核 CPU、总线和 DDR 不属于本轮音频优化方案。

IP 版本、来源、参数与未采用原因见 [IP_ASSESSMENT.md](IP_ASSESSMENT.md)。

## 复现

```powershell
# RTL 回归（需要 ModelSim 路径）
& ./project/resource_optimization_lab/sim/run.ps1 `
  -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'

# 两个候选的 Gowin 构建（需要本机 Gowin IDE）
python project/resource_optimization_lab/tools/build.py `
  --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' `
  --variant all
```

构建产物在本机 `impl/`，不提交 ModelSim 库、日志缓存或 `.fs`。构建脚本会记录源文件哈希、资源、IO 和时序，避免把旧报告当成新结果。

完整结果见 [VALIDATION.md](VALIDATION.md)。当前最有迁移价值的是 `shared_sine8_complete`；`pruned_sine8` 是资源下限，三个 probe 是算子级证据。共享候选最新 PnR 为 `3894 Logic / 2277 Register / 1 BSRAM / 2 DSP / 19 IO`，setup/hold 最差报告 slack 为 `6.547/0.247 ns`。

## 当前不做的事

本实验不修改正式工程、不把固定单音色方案包装成最终产品、不通过降低音量掩盖失真、不使用 false path 隐藏共享调度的时序问题。`harmonic_piano` 的板测选择仍由 `audio_clean_lab` 记录，本实验只比较架构成本。
