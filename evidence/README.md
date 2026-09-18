# 验证证据与试听

所有音频均由RTL仿真导出，**不是板卡模拟录音**。用户已接受当前电脑默认音色；实际耳机仍有随音高变化的尖锐声。不要把这些WAV当作板卡音质达标证明，也不能送回FPGA当预录音播放。

## 可试听文件

| 文件 | 内容 |
|---|---|
| [baseline_preview.wav](audio/baseline_preview.wav) | 当前16秒演示，全段固定×8增益，无逐段归一化 |
| [baseline_raw.wav](audio/baseline_raw.wav) | 同一仿真保留FPGA数字电平 |
| [instrument_original.wav](audio/instrument_original.wav) | 最初认可的六秒原单声部参考、C4/E4/G4/C5；原数字幅度 |

当前演示包含原单音、音量/静音、三档力度、普通延音、选择性延音、四声部、跨八度八音和弦；不是多音色/滑音/弯音全功能演示。详细时间见[工程说明](../project/expression_baseline/README.md)。GitHub可能需下载WAV再播放。

## 历史验证 · 2026-09-18

[baseline_2026-09-18](baseline_2026-09-18/audio_analysis.json)保存4项ModelSim日志、音频数值分析、Gowin实现报告/时序HTML和原固件指纹。报告中本机工作区路径替换为通用标记，未重新执行历史构建。

| 层级 | 结果和边界 |
|---|---|
| 声部 | 192308样本与原voice/力度整数参考一致；该一致性检查不是独立物理钢琴模型 |
| 混音 | 2000组，包括921次正负饱和；全宽求和与增益时序 |
| 串行顶层 | 2048帧、48音符事件、17配置命令、最大8声部；真实1040系统周期/采样 |
| 完整渲染 | 769232样本，16秒音频；压缩采样间空闲系统周期，但保留包络/事件采样数 |
| 数字声音 | 峰值−2602..3206，C4≈261.631Hz，无最终削波，尾音归零；旧原始C4及尾音96154样本精确匹配 |
| 实现 | 4887 Logic、1088寄存器、8 BSRAM、13 DSP，setup 2.543ns、hold 0.125ns；PR1014仍有；不是整机/外部电气延迟验收 |

历史manifest引用18:23的4A3BBD…；最后本机构建为18:25的F56643…，记录于[original_artifact.json](baseline_2026-09-18/original_artifact.json)。本仓库不带.fs；后续用自己的构建哈希记录板测。Git统一源码换行后，不用历史原始字节SHA判断源码等价。

## 从仓库复现

执行根README的baseline仿真；日志、样本和两份WAV生成在`project/expression_baseline/sim/`。脚本检查编译、错误文本和PASS标记，不仅检查返回码。

干净克隆没有旧`instrument/sim/demo_samples.txt`，因此分析器的“与历史instrument文本逐样本比较”可选项会显示0；baseline_voice_tb仍比较独立实例，完整渲染仍检查音高/包络/力度/音量/静音。如需重新取得那项96154样本对照，先运行instrument完整仿真（其分析需NumPy），再运行baseline；不能把可选跳过写成已经对比。当前接手验证另记录于[仓库复现记录](REPRODUCIBILITY.md)。

新板测用[模板](../templates/BOARD_TEST.md)，记录源码commit与实际bitstream哈希；音频模拟定位记录见[NOISE_DIAGNOSIS](../project/audio_quality/NOISE_DIAGNOSIS.md)。
