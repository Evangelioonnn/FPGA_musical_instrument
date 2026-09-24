# 验证记录 · 2026-09-24

分支：`codex/audio-noise-lab`。角色：A；允许目录：`project/audio_noise_lab/` 及本证据页。目标：在不改正式矩阵工程的前提下，给公共音频输出链路准备可复现的软件对照。

## RTL 结果

命令：

```powershell
& ./project/audio_noise_lab/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' -Benches 'gain_tb,tx_rate_tb,tx_format_tb,upsampler2_tb,upsampler4_tb,activity_gate_tb'
```

结果：

- `GAIN_TB_PASS`：遍历 65,536 个有符号 16 位输入；×2 饱和 32,768 个，×4 饱和 49,152 个。
- `TX_RATE_TB_PASS`：基线/×2/×4 分别得到 24/48/96 个完整帧；×4 BCK 半周期为 3–4 个 50 MHz 时钟。
- `TX_FORMAT_TB_PASS`：两种速率均按每声道 20 个 BCK 边沿、LSBJ 数据解码正确。
- `UPSAMPLER2_TB_PASS`、`UPSAMPLER4_TB_PASS`：9/17 个有符号插值值逐点符合独立 oracle。
- `ACTIVITY_GATE_TB_PASS`：三音色门控前后 sample、busy、held 逐周期一致。

## PnR 结果

构建命令：

```powershell
python project/audio_noise_lab/tools/build.py --variant baseline
python project/audio_noise_lab/tools/build.py --variant gain_x2
python project/audio_noise_lab/tools/build.py --variant gain_x4
python project/audio_noise_lab/tools/build.py --variant oversample_x2
python project/audio_noise_lab/tools/build.py --variant oversample_x4
```

| 版本 | Logic | Register | BSRAM | DSP | IO | Setup/hold 最差余量 ns | 结论 |
|---|---:|---:|---:|---:|---:|---:|---|
| baseline | 23310 | 9329 | 40 | 97 | 15 | +0.084 / +0.164 | 可上板 |
| gain_x2 | 23322 | 9329 | 40 | 97 | 15 | +0.032 / +0.190 | 可上板 |
| gain_x4 | 22384 | 9328 | 40 | 97 | 15 | +0.124 / +0.048 | 可上板 |
| oversample_x2 | 23508 | 9362 | 40 | 97 | 15 | +0.014 / +0.227 | 可上板，时序余量紧 |
| oversample_x4 | 23296 | 9363 | 40 | 97 | 15 | +0.780 / +0.190 | 可上板 |
| activity_gate | — | — | — | — | — | — | PnR 失败，336 nets unrouted |

所有已通过版本保留 Gowin PR1014 警告；该警告不是 setup/hold 违例，但意味着 `sys_clk` 使用了通用路由资源，正式比赛顶层仍需单独优化时钟入口。

## 真实板测结果

2026-09-24 用户完成五个 `.fs` 的首轮板上试听，详见 [BOARD_TEST](BOARD_TEST.md)：

- 五版均仍有噪声，噪声随音高变化的规律没有改变。
- USB 与 USB＋12 V 的听感没有明显差异。
- `gain_x2`/`gain_x4` 只提高整体响度；起音突音主观上较不明显，但噪声未消失。
- `oversample_x2`/`oversample_x4` 未听出实质改善。
- FM 噪声最大，默认音色为较弱的尖锐声，拨弦最干净；静音底噪各版本接近。
- 默认音色同时按 S1/S2 的颤抖单独记录为可能的拍频/相位叠加现象。

仍未完成示波器采集，也没有证明噪声的具体硬件节点或根因。数字增益版本不能据此视为模拟失真修复；继续使用时应先降低耳机/音箱音量。
