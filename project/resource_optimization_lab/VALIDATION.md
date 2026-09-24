# 资源优化验证记录

分支：`codex/resource-optimization-lab`。角色：A。范围：独立架构实验，不替换正式 `matrix_playable`。

## 现有基线

最近一次八声部三音色矩阵版构建：`23659 Logic / 9684 Register / 40 BSRAM / 97 DSP / 19 IO`，50 MHz setup/hold 最差余量 `0.251/0.048 ns`。

## 1. 正弦-only 资源下限

`pruned_sine8` 保留矩阵输入、八声部事件身份、原正弦 DDS+ADSR、音量和 PT8211，仅移除 FM/拨弦声部。独立 `resource_pruned_tb` 通过，8 个起音事件和连续音频帧无 deadline；Gowin PnR 通过。

| 变体 | Logic | Register | BSRAM | DSP | IO | setup/hold 违例 |
|---|---:|---:|---:|---:|---:|---|
| matrix_playable 基线 | 23659 | 9684 | 40 | 97 | 19 | 0/0 |
| pruned_sine8 | 4803 | 2485 | 8 | 9 | 19 | 0/0 |

这给出了“删除未选音色”的资源下限，但不支持三音色，因此不能作为最终作品固件。

## 2. 正弦 ROM 共享探针

`shared_sine8_probe` 让 8 个动态相位轮流访问 1 个同步正弦 ROM；`resource_sine_tb` 与 8 个独立 ROM 的参考逐帧比较通过。

| 变体 | Logic | Register | BSRAM | DSP | setup/hold 违例 |
|---|---:|---:|---:|---:|---|
| duplicated_sine8_probe | 592 | 355 | 8 | 0 | 0/0 |
| shared_sine8_probe | 655 | 430 | 1 | 0 | 0/0 |

共享 ROM 节省 7 个 BSRAM，代价是调度寄存器和控制逻辑增加；在 BSRAM 需要为显示/延迟线预留时有价值。

## 3. 乘法器共享探针

`shared_mult8_probe` 逐个处理 8 组有符号 32×32 乘积，和并行参考逐帧一致；`resource_mult_tb` 通过，两个 19-IO 顶层均完成 50 MHz PnR。

| 变体 | Logic | Register | BSRAM | DSP | setup/hold 违例 |
|---|---:|---:|---:|---:|---|
| duplicated_mult8 | 749 | 542 | 0 | 32 | 0/0 |
| shared_mult8 | 938 | 1103 | 0 | 4 | 0/0 |

共享乘法器能显著降低 DSP，但需要更多控制寄存器和严格调度。该探针还不是完整 FM，因为真实 FM 的多个乘法存在数据依赖；下一步必须以完整声部流水的最坏周期为准。

## 4. 完整共享正弦候选

`resource_shared_sine_bank` 保留每声部独立相位、包络、释放、按键 token 和混音状态，每个采样帧轮询 8 个声部，共享一个同步正弦 ROM 和一个波形×包络乘法路径。`resource_shared_sine_tb` 完成 8 个起音、连续采样帧、无未知输出和无 deadline 检查；Gowin PnR 通过。

| 变体 | Logic | Register | BSRAM | DSP | IO | setup/hold 违例 |
|---|---:|---:|---:|---:|---:|---|
| shared_sine8_complete | 3894 | 2277 | 1 | 2 | 19 | 0/0 |

这是当前最值得迁移的正弦核心路线。`resource_shared_sine_compare_tb` 在同一事件边界下与正弦-only 生产参考逐样本比较 624 帧，0 mismatch；共享调度的 50 MHz 报告 setup/hold 最差 slack 为 `6.547/0.247 ns`。它尚未上板试听，不能写成音质验收。

## 5. 官方 IP 结论

本机 IP 目录确认存在 `DDS_II`、`RAM_pROM`、`RAM_SDPB`、`DSP_MULT`、`FIFO_SC` 和 `FFT`。当前 HDL 已被 Gowin 推断为 BSRAM/DSP，显式 IP 不会自动跨声部共享。`DDS_II` 和显式 `DSP_MULT` 只有在同一 testbench 下证明样本时序、器件支持和资源更好时才替换；FFT 留给 C 的显示支线，不接入音频主路径。

本轮没有把加密 IP 封装直接塞进正式工程，避免引入未锁定的仿真库、同步延迟和参数版本。IP 评估记录见 [IP_ASSESSMENT.md](IP_ASSESSMENT.md)。

## 未完成和迁移边界

- 共享正弦候选当前只接受 timbre 0；FM/拨弦仍需独立共享算子或少量并行保留。
- 所有结果是 RTL/PnR 证据，不是板卡音质验收；没有改写 Flash，也没有提交 `.fs`。
- 迁移到最终工程前，必须完成：逐样本音频对照、矩阵/旋钮回归、三音色资源预算、完整 50 MHz PnR 和至少一次板测。
- 不使用 false path 隐藏共享调度的截止问题；当前输入 false path 只沿用已有异步输入约束。
