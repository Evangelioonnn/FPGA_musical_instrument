# audio_noise_lab：板卡噪声软件对照工程

本工程是 `codex/audio-noise-lab` 分支上的诊断实验，不是最终产品顶层。它沿用已经板测过的 4×4 矩阵输入、一个板载按键循环三种音色、8 声部实例、原正弦 DDS＋ADSR `68/6/32768/3`、拨弦自然衰减、FM 自然衰减和 PT8211 LSBJ 输出。旋钮与另外两颗板载按键在本工程中没有接入。

用户已经确认耳机和有源音箱在同一 3.5 mm 输出上听到同类随音高变化的尖锐声；因此本工程只验证能由 FPGA 数字链路解释的候选因素，不能把任何一版写成噪声已经修复。真实音质仍要由同一板卡、同一负载和同一操作顺序试听，最好配合示波器测量。

2026-09-24 首轮用户板测已完成：五个可下载版本都保留原噪声规律；只接 USB 与 USB＋12 V 无明显差异。`gain_x2`/`gain_x4` 只是整体更响，`oversample_x2`/`oversample_x4` 未听出实质改善。FM 噪声最大，默认音色是较弱的尖锐声，拨弦最干净；静音底噪基本相同。详见 [BOARD_TEST](BOARD_TEST.md)。

## 可下载版本

构建产物在本机 `project/audio_noise_lab/impl/pnr/` 下。`.fs` 被 `.gitignore` 排除，不提交到仓库；源码可随时重建。下表的 SHA256 记录在同名 `impl/*_build_provenance.json` 中。

| 版本 | 顶层 | 改变的因素 | PnR 状态 | 试听顺序 |
|---|---|---|---|---|
| `audio_noise_baseline.fs` | `noise_lab_top_baseline` | 原 PT8211 采样率与原三音色路径 | 通过；setup 0.084 ns，hold 0.164 ns | 第一版，作为当天对照 |
| `audio_noise_gain_x2.fs` | `noise_lab_top_gain_x2` | PCM 输出数字幅度乘 2，带饱和 | 通过；setup 0.032 ns，hold 0.190 ns | 外部音量先调低 |
| `audio_noise_gain_x4.fs` | `noise_lab_top_gain_x4` | PCM 输出数字幅度乘 4，带饱和 | 通过；setup 0.124 ns，hold 0.048 ns | 外部音量先调低，短按即可 |
| `audio_noise_oversample_x2.fs` | `noise_lab_top_oversample_x2` | PT8211 帧率乘 2，线性插值填充中间样本 | 通过；setup 0.014 ns，hold 0.227 ns | 最后再测，余量最紧 |
| `audio_noise_oversample_x4.fs` | `noise_lab_top_oversample_x4` | PT8211 帧率乘 4，线性插值填充中间样本 | 通过；setup 0.780 ns，hold 0.190 ns | 最后再测，短旋律即可 |
| `audio_noise_activity_gate.fs` | `noise_lab_top_activity_gate` | 仅更新当前音色声部，减少未选中音色翻转 | **PnR 失败，336 条网络未布线** | 不下载、不试听 |

所有通过版本均为 15 个 IO，复用矩阵 J8、板载键 Y12、音频 Y17/AB17/AA16、功放使能 AB16、状态灯 J16。过采样版本仍保持合成采样率和包络时间不变；改变的是 PT8211 串行帧频率。输出格式继续是每声道 20 个 BCK 边沿，其中前 4 位为零、随后 16 位为 MSB-first 数据，符合本板采用的 LSBJ 发送器模型。

## 上板操作

1. 先断电，按 [matrix_playable 接线表](../input/matrix_playable/WIRING.md) 接 PMOD1/J8 的矩阵；矩阵不接额外 3.3 V、5 V 或 GND。确认旋钮不参与本工程。
2. 在 Gowin Programmer 选择 SRAM 下载，不写 Flash。Designer 重新打开 `audio_noise_lab.gprj` 后，确认下载对应版本的顶层和约束；更换版本后重新打开工程或重新执行构建脚本。
3. 矩阵按键和音色按键行为与 `matrix_playable` 相同：USER_BUTTON2/Y12 每次循环原默认、拨弦、FM；只改变新按下的音符，旧尾音不截断。
4. 固定相同的短旋律和相同音量，先听基准，再按 ×2、×4、过采样 ×2、过采样 ×4。每版分别记录稳态、起音、松键、快速重弹、音色切换和静音时的尖锐声、突音和底噪。
5. 增益版一定先把耳机或有源音箱音量调低，确认没有削顶或过响后再比较。若增益版只是更响，不能据此称为失真改善。

板测记录使用 [BOARD_TEST.md](BOARD_TEST.md)。必须注明固件文件名、SHA256、供电、输出设备和试听顺序；“电脑 WAV 干净”与“板卡模拟输出干净”分开写。

## 复现

```powershell
# 生成 Gowin 工程文件
python project/audio_noise_lab/tools/create_project.py

# ModelSim：需要给脚本传入本机 ModelSimBin；本轮独立 bench 全部通过。
& ./project/audio_noise_lab/sim/run.ps1 `
  -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' `
  -Benches 'gain_tb,tx_rate_tb,tx_format_tb,upsampler2_tb,upsampler4_tb,activity_gate_tb'

# 单独构建某一版；默认输出写入 project/audio_noise_lab/impl/。
python project/audio_noise_lab/tools/build.py --variant baseline
python project/audio_noise_lab/tools/build.py --variant gain_x2
```

仿真覆盖有符号 16 位全输入增益饱和、PT8211 帧率与 LSBJ 载荷、×2/×4 插值独立期望值、三音色门控前后行为逐周期一致。仿真通过不代替 Gowin PnR，也不代替真实板卡试听。

## 解释边界

- 增益实验改变了 DAC 数字工作点，可能暴露低电平非线性，也可能只是让原有杂音和声音一起变响；它不是自动增益修复。
- 过采样实验只测试 PT8211 重建条件。它没有改变合成频率、ADSR 步进或矩阵扫描时序；若板上没有改善，下一步应优先测 BCK/WS/DIN 和 PT8211、LMV321、NS4263 各节点。
- 门控实验的 RTL 数值等价，但当前物理实现失败，不能使用其未生成的比特流。
- 现有工程保留了 Gowin 的 PR1014 时钟资源警告；所有“通过”均表示无 setup/hold 违例和有 `.fs`，不表示模拟音质或端到端延迟达标。
