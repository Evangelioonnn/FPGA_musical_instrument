# 验证证据与试听

当前先看[音频V2及总体听感反馈](audio_core_v2_2026-09-29/BOARD_LISTENING.md)、[音频接入包验证](../project/audio_integration/VALIDATION.md)和[证据索引](INDEX.md)。下文音频表与复现段保留9月18～22日的历史参考，不能用其旧默认音色/待板测文字覆盖当前状态。

音频来源逐项标注，**均不是板卡模拟录音**。baseline、lab、输入序列、delay及candidate_fm/pluck_rtl来自RTL；candidate_fm/pluck_offline是保留的Python浮点候选。用户已板上试听新RTL，主体与WAV相符，pluck杂音很轻、FM杂音明显，详见[板测反馈](timbre_rtl_2026-09-19/BOARD_LISTENING.md)。

EC11独立探针已完成用户耳机板测，见[EC11板级试听](ec11_board_2026-09-19/BOARD_LISTENING.md)。不要把这些WAV当作板卡音质达标证明，也不能送回FPGA当预录音播放。

各日期证据包和它们的通过范围见[证据索引](INDEX.md)。

9月22日新增[矩阵演奏证据](matrix_playable_2026-09-22/README.md)：一份八声部三音色真实输入候选，数字/PnR与三音色参考音的完成项按包内记录。矩阵/板载按键/指示灯的实际验收和音质仍待用户完成。

9月20日新增[旋钮控制证据](knob_suite_2026-09-20/README.md)：11项仿真、五份七IO/50MHz构建、完整演奏数学核对及14份WAV。后来用户完成首次板测，功能认可和新增杂音分别见[板测反馈](knob_suite_2026-09-20/BOARD_LISTENING.md)；七段试听与实际旋钮操作顺序见[验收指南](../docs/project/KNOB_REVIEW_2026-09-20.md)。

9月19日夜间新增[system v0证据](system_v0_2026-09-19/README.md)：18项系统仿真、3项效果仿真、输入链/长音试听、8/16/32资源时序及可复现脚本。32声部时序失败已保留。

9月19日新增[FM/拨弦RTL证据](timbre_rtl_2026-09-19/README.md)：两种独立单声部、浮点数值对照、命令/串行验证和五引脚试听顶层资源时序；用户后续听感另列板测记录，数字构建报告不代表模拟验收。

## 历史试听文件

| 文件 | 内容 |
|---|---|
| [baseline_preview.wav](audio/baseline_preview.wav) | 旧baseline的16秒演示，全段固定×8增益，无逐段归一化 |
| [baseline_raw.wav](audio/baseline_raw.wav) | 同一仿真保留FPGA数字电平 |
| [instrument_original.wav](audio/instrument_original.wav) | 最初认可的六秒原单声部参考、C4/E4/G4/C5；原数字幅度 |
| [input_sequence_preview.wav](audio/input_sequence_preview.wav) | 6秒逻辑输入链演奏，仍原音色，固定×8 |
| [lab_c4_preview.wav](audio/lab_c4_preview.wav)、[lab_a4_preview.wav](audio/lab_a4_preview.wav) | 10秒长音诊断，固定×8；对应[原始C4](audio/lab_c4_raw.wav)/[原始A4](audio/lab_a4_raw.wav)保留码值 |
| [delay_preview.wav](audio/delay_preview.wav) | 原16秒演示经独立RTL短延迟＋尾音，固定×4 |
| [candidate_fm_offline.wav](audio/candidate_fm_offline.wav)、[candidate_pluck_offline.wav](audio/candidate_pluck_offline.wav) | 各7.5秒独立新音色选择，只是离线浮点候选 |
| [candidate_fm_rtl.wav](audio/candidate_fm_rtl.wav)、[candidate_pluck_rtl.wav](audio/candidate_pluck_rtl.wav) | 各7.5秒，真正来自新单声部定点RTL；原算法电平，无归一化；第七段是单个C4 |
| [fm_monitor_preview.wav](audio/fm_monitor_preview.wav)、[pluck_monitor_preview.wav](audio/pluck_monitor_preview.wav) | 核心RTL样本施加板级整数衰减后统一×32试听，保留新增量化影响；不是板卡录音，见[说明](timbre_rtl_2026-09-19/BOARD_LISTENING.md) |

旧baseline演示包含原单音、音量/静音、三档力度、普通延音、选择性延音、四声部、跨八度八音和弦；不是当前五音色/滑音/弯音全功能演示。详细时间见[历史工程说明](../project/expression_baseline/README.md)。GitHub可能需下载WAV再播放。

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

## 历史baseline复现

按[旧baseline工程](../project/expression_baseline/README.md)的仿真命令复现该对照；日志、样本和两份WAV生成在`project/expression_baseline/sim/`。当前根README推荐V2和接入包，不再提供baseline默认命令。脚本检查编译、错误文本和PASS标记，不仅检查返回码。

干净克隆没有旧`instrument/sim/demo_samples.txt`，因此分析器的“与历史instrument文本逐样本比较”可选项会显示0；baseline_voice_tb仍比较独立实例，完整渲染仍检查音高/包络/力度/音量/静音。如需重新取得那项96154样本对照，先运行instrument完整仿真（其分析需NumPy），再运行baseline；不能把可选跳过写成已经对比。当前接手验证另记录于[仓库复现记录](REPRODUCIBILITY.md)。

新板测用[模板](../templates/BOARD_TEST.md)，记录源码commit与实际bitstream哈希；音频模拟定位记录见[NOISE_DIAGNOSIS](../project/audio_quality/NOISE_DIAGNOSIS.md)。
