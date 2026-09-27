# 钢琴复音杂音：输出链路隔离实验

**这是可上板的对照候选，未宣称杂音已经修复。** 保留你认可的01精度钢琴和06柔和拨弦，在同一份固件里切换；八声部、双区、矩阵和旋钮接法沿用上一轮。本轮不再试听旧默认/FM，也不修改上一轮文件。

先看[上板验收步骤](BOARD_TEST.md)，技术边界见[SPEC](SPEC.md)，实测资源和数字结果见[VALIDATION](VALIDATION.md)。历史听感依据为[9月27日反馈](../../evidence/audio_palette_lab_2026-09-26/BOARD_LISTENING_2026-09-27.md)。

| 独立Designer工程 | 改动 | 注意 |
|---|---|---|
| [00_control](variants/00_control/00_control.gprj) | 统一对照：01钢琴＋06拨弦 | 默认钢琴、音量18；以前默认24，不能直接按启动响度比较 |
| [01_piano_headroom](variants/01_piano_headroom/01_piano_headroom.gprj) | 钢琴固定衰减约18dB，拨弦不动 | 钢琴最大约等于旧18格；不会因多按键而自动降低旧音 |
| [02_edge_spacing](variants/02_edge_spacing/02_edge_spacing.gprj) | 保持原PCM，错开BCK/DIN/WS翻转沿 | 和00按相同音量比较，检验发送边沿相关问题 |
| [03_polarity](variants/03_polarity/03_polarity.gprj) | 左右声道一起反相 | 与00响度/音色理论相同，是诊断版本；不是左右互反 |

每个目录都有自己的 `impl/pnr/同名.fs`，本机已构建；Git不保存比特流，克隆后需重建。没有把几个.fs藏在一个Designer工程里。顶层分别为 `output_00_control`、`output_01_piano_headroom`、`output_02_edge_spacing`、`output_03_polarity`，全部19个IO。打开对应gprj后确认Top Module，再按以前的Programmer流程做SRAM下载。

四版开始都是钢琴，旋钮是音量，启动18/24；板载S1切音色、S2延音、S4短按依次切音量/左区八度/右区八度/释放，长按约1秒止音。默认左区S1–S8=C3到C4白键，右区S9–S16=C4到C5白键；矩阵编号与板载S1/S2要区分。

## 复现

Python 3，ModelSim和Gowin路径支持参数；音频分析需NumPy。以下在仓库根目录运行，常规Python名称按本机替换：

```powershell
python project/audio_output_lab/tools/generate.py
python project/audio_output_lab/sim/run.py
python project/audio_output_lab/tools/check_math.py
python project/audio_output_lab/sim/run.py --no-compile --benches output_render_tb
python project/audio_output_lab/tools/extra_tests.py
python project/audio_output_lab/tools/analyze_render.py
python project/audio_output_lab/tools/build.py --variant all
python project/audio_output_lab/tools/record_validation.py
python tools/check_repository.py
```

`build.py --gowin 路径`、`sim/run.py --modelsim 目录`、`extra_tests.py --modelsim 目录`可换工具。record_validation检查当前文件哈希与构建记录，不拿旧fs冒充新源码。只生成/验证本机文件，没有操作板卡或GitHub。

## 当前判断

用户报告的门槛随音量、音区和音数变化，是重要线索，但不能直接认定16位混音削顶，更不能断言硬件损坏。现有04理论双音在20档的保守峰值约1350PCM、三音约2026PCM，远低于32767。还要考虑板上实际数字输出、DAC/滤波/功放的非线性或耦合，以及原有分量随响度变得可闻。

C3/D3本来就有约16Hz差频包络，C4/D4约32Hz；这解释正常叠加的部分颤动，**不能解释为用户额外粗糙声、起音声都正常**。本轮用相同PCM、相同音量的发送时序/极性对照继续区分；01降低电平是缓解候选，单靠它不能找出失真发生在哪一级。

本轮未修改02/03旧自然衰减候选的分层尾音，优先保留已喜欢的01。选择性延音、滑音、增加复音和显示整合另轮继续。
