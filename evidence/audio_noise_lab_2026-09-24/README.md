# audio_noise_lab 夜间任务证据

本包对应分支 `codex/audio-noise-lab`，记录 2026-09-24 软件噪声对照工程的数字验证和 PnR 结果。它没有板测结论，也没有把候选版本合入正式整机。

工程入口：[audio_noise_lab](../../project/audio_noise_lab/README.md)。

通过范围：六项独立 RTL bench；五个输出变体生成新的 15-IO `.fs` 并完成 50 MHz setup/hold 检查。失败范围：`activity_gate` 的 PnR 报告显示 336 条未布线网络，不能下载。真实音质、示波器波形、PT8211/DAC/模拟链路根因都未验证。

构建产物被仓库规则排除，保存在执行机器的 `project/audio_noise_lab/impl/pnr/`；交接时应使用源码和 `tools/build.py` 重建，不复制旧 `.fs`。
