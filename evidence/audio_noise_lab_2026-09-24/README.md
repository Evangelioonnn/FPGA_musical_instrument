# audio_noise_lab 夜间任务证据

本包对应分支 `codex/audio-noise-lab`，记录 2026-09-24 软件噪声对照工程的数字验证、PnR 结果和首轮用户板测。它没有把候选版本合入正式整机。

工程入口：[audio_noise_lab](../../project/audio_noise_lab/README.md)。

通过范围：六项独立 RTL bench；五个输出变体生成新的 15-IO `.fs` 并完成 50 MHz setup/hold 检查。失败范围：`activity_gate` 的 PnR 报告显示 336 条未布线网络，不能下载。真实音质、示波器波形、PT8211/DAC/模拟链路根因都未验证。

构建产物被仓库规则排除，保存在执行机器的 `project/audio_noise_lab/impl/pnr/`；交接时应使用源码和 `tools/build.py` 重建，不复制旧 `.fs`。

## 用户板测摘要

用户于 2026-09-24 对五个可下载版本完成试听。只接 USB 与 USB＋12 V 的听感没有明显差异；五版都保留原有随音高变化的噪声规律。`gain_x2` 和 `gain_x4` 只使整体声音更响，起音突音主观上较不突出；`oversample_x2` 和 `oversample_x4` 未听出实质改善。三种音色中 FM 噪声最大，默认音色是较弱的尖锐声，拨弦最干净；静音底噪基本相同。默认音色同时按 S1/S2 时出现的颤抖暂列为可能的拍频/相位叠加现象，另行分析。

本轮没有示波器波形，不能据此确定 PT8211、DAC/低通、NS4263 或其他模拟节点的根因，也不能写成噪声已修复。
