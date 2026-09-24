# audio_clean_lab：干净音色候选工程

这是独立于正式整机的音色试听实验。它复用已经验证的 4×4 矩阵、八声部事件分配、音量/释放控制、USER_BUTTON2 音色切换和 PT8211 输出，只替换 timbre 0 的候选音色。拨弦仍是 timbre 1 的已知对照，旧 FM 仍是 timbre 2 的问题对照。

本工程的目标是尽快找出一个板上听感干净、可以替代默认音色的方案。它不能证明公共模拟链路已经修复；所有结论仍必须以同一板卡的 SRAM 下载和用户试听为准。

## 下载版本

构建产物在本机 `impl/pnr/`，不进入 Git。四个顶层使用相同的矩阵接线和按键操作：

| 文件 | timbre 0 | timbre 1 | timbre 2 | 用途 |
|---|---|---|---|---|
| `audio_clean_reference_x8.fs` | 原正弦波，声部级约 ×8 电平 | 拨弦 | 原 FM | 检查低电平 DAC/模拟链路假设 |
| `audio_clean_harmonic_piano.fs` | 低阶加法谐波波形 | 拨弦 | 原 FM | 首选的柔和电钢琴方向 |
| `audio_clean_low_fm.fs` | 低复杂度双谐波波形 | 拨弦 | 原 FM | 低高频边带候选，暂不等同于完整 FM 重写 |
| `audio_clean_triangle.fs` | 三角波，低高频能量 | 拨弦 | 原 FM | 资源最省的干净兜底 |

USER_BUTTON2 每按一次循环三种音色，矩阵按键行为与 `matrix_playable` 相同。试听时先把外部音量调低；`reference_x8` 的整体电平会明显高于旧基准。

## 候选设计

`clean_voice.v` 使用 FPGA 内部硬件逻辑和同步波表，不播放预录 PCM，也不使用软核 CPU。四个模式保留原 ADSR `68/6/32768/3`，先只改变波形和有效电平，便于判断噪声来源。加法波形只保留低阶谐波，避免把 FM 的高频边带问题带入首选候选。

## 复现

```powershell
python project/audio_clean_lab/tools/create_project.py
& ./project/audio_clean_lab/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' -WorkLibrary work_audio_clean -Benches 'clean_voice_tb,clean_render_tb'
python project/audio_clean_lab/tools/build.py --variant all
```

构建输出的 `*_build_provenance.json` 记录顶层、源文件指纹、资源、IO 和时序结果。`impl/`、ModelSim 库、日志和 WAV 只保留在本机。

## 边界

- 这是音色候选实验，不替换 `project/input/matrix_playable` 或默认参考音色。
- 仿真和 PnR 通过不等于板卡音质通过。
- 如果四个候选仍出现同样的随音高尖锐声，继续更换音色的收益很低，应转到 PT8211、LMV321、NS4263 和实际 BCK/WS/DIN 波形测量。
