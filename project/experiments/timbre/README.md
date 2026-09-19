# FM 与拨弦：独立单声部音色实验

2026-09-19，用户认可两份离线候选，授权同时实现。任务分支`feat/fm-pluck-rtl`基于`cac8fe0`，依赖尚未合并的system v0分支。A负责本轮，修改范围为本目录及对应证据/交接说明；接口、目标和验收见[RTL_SPEC](RTL_SPEC.md)。

两种音色现在都有独立的单声部定点RTL、数学对照、事务测试和五引脚试听工程。**用户已上板试听，两者主体与WAV相符；pluck杂音很轻、FM杂音明显，尚未通过完整音质验收。** 见[听感记录及衰减后对照](../../../evidence/timbre_rtl_2026-09-19/BOARD_LISTENING.md)。未接入整机音色选择和多声部管理，原instrument和expression_baseline默认声音仍保留。最终数字验证与构建指纹见[本轮证据](../../../evidence/timbre_rtl_2026-09-19/README.md)。

| 模块 | 声音生成 | 实现说明 |
|---|---|---|
| [FM](fm/README.md) | 1:1双算子相位调制，随时间变柔和的电钢琴/铃音方向 | 数学正弦ROM、插值、指数包络、共享乘法运算 |
| [拨弦](pluck/README.md) | 程序生成激励、分数延迟、低通反馈的弦振动方向 | 确定性噪声、去均值、同步状态RAM；不是采样录音 |

两者均支持36..84音号、0..256力度、note_on/off、150ms释放、重触发与panic。事务字段和反压由[共用契约](RTL_SPEC.md)定义。实时变调、滑音、踏板、音色切换和新音色复音需要后续适配，不能把既有system功能自动算作已适用于这两个新模块。

## 试听与上板准备

- [FM真实RTL试听](../../../evidence/audio/candidate_fm_rtl.wav)
- [拨弦真实RTL试听](../../../evidence/audio/candidate_pluck_rtl.wav)

新音频直接来自RTL的16位数字样本，没有按段归一化。十个0.75秒单音段：C3、G3、C4、E4、G4、C5、C4中等力度、C4弱/中/强力度；各段按住约0.53秒、释放约0.15秒。第七段用单个C4代替旧离线候选的三音和弦，明确本次是单声部。拨弦使用确定性的硬件随机激励，与旧NumPy噪声波形不逐点相同。

板级工程分别为`board/fm/fm_probe.gprj`、`board/pluck/pluck_probe.gprj`；正确顶层为`fm_probe_top`和`pluck_probe_top`，均仅5个已核验物理IO。重新打开Designer后确认顶层，不能选择内部voice为板级顶层。输出来自实时合成，同一单音送左右声道，7.5秒循环。两个工程均固定将算法输出除以32，再限制在−512..511码；电脑WAV保留原算法电平，因此电脑试听与板上绝对响度不同，且两个音色之间未做响度均衡。量化和模拟链路还须真实试听。

实现阶段仅生成构建产物；用户随后按SRAM试听步骤给出了上述反馈，没有收到Flash操作报告。后续板测继续记录实际.fs哈希，不覆盖原默认音色的噪声定位记录。`pa_en=0`和PT8211格式沿用已确认路径。

## 复现

在仓库根运行，下例工具路径按本机替换；Python需NumPy。三个仿真目录使用各自ModelSim工作库，可独立运行。

```powershell
& ./project/experiments/timbre/fm/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' -PythonExe python
& ./project/experiments/timbre/pluck/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' -PythonExe python
& ./project/experiments/timbre/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'
python project/experiments/timbre/tools/create_projects.py
python project/experiments/timbre/tools/build.py --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'
python project/experiments/timbre/tools/record_evidence.py
```

voice数值渲染压缩空闲系统周期，按实际Fs解释样本；共享probe测试以真实50MHz/1040周期接收串行数据。build.py核对构建前后源码哈希；record_evidence.py检查时序、样本测试和构建来源后更新证据。五引脚自动演示的综合资源包含序列器/传输，常量输入也可能使通用逻辑被优化；不是多声部整机预算。独立内部时序通过也不等于耳机音质、外部DAC电气或≤10ms输入到声音的端到端验收。

## 保留的离线候选

两份音频采用同一乐谱：C3、G3、C4、E4、G4、C5、C大三和弦、C4的三档力度，每段0.75秒，合计7.5秒。全程固定系数，无逐音/逐段归一化；两个候选的绝对响度不等同，先关注音色与触键感。

- [FM候选](../../../evidence/audio/candidate_fm_offline.wav)：双算子相位调制，调制深度快速衰减，电钢琴/铃音方向。
- [拨弦候选](../../../evidence/audio/candidate_pluck_offline.wav)：随机激励、分数延迟、低通反馈，拨弦方向；高音音准和衰减须进一步定点验证。

复现：仓库根执行 `python project/experiments/timbre/render_candidates.py`（需要NumPy）。这些WAV只供试听，不回灌FPGA播放。

## 参考与移植成本

2026-09-19重新读取了这些上游入口；本目录没有复制其实现。历史逐文件许可记录见[开源参考](../../../docs/history/TIMBRE_PLAN.md)。

| 路线 | 参考 | FPGA实现需要处理 |
|---|---|---|
| 小型FM | [OPL3 FPGA](https://github.com/gtaylormb/opl3_fpga) | 独立相位、调制索引与包络、定点溢出、每样本时分调度；上游平台/CPU总线不照搬，LGPL采用方式另查 |
| 拨弦 | [STK Plucked.cpp](https://github.com/thestk/stk/blob/master/src/Plucked.cpp) | 分数延迟调音、反馈稳定、逐音初始化、释放阻尼；C++算法不能直接转IP |
| 更丰富弦模型 | [Plaits string_engine.cc](https://github.com/pichenettes/eurorack/blob/master/plaits/dsp/engine/string_engine.cc) | excitation/resonator组织可参考；该文件MIT，其他依赖逐文件核对 |

估算而非综合结果：单拨弦声部最低C3约需要368个16位延迟样本；若扩到C2约736样本。32声部的存储、双端口带宽和乘法调度需要重新预算。FM至少需要两个相位状态/声部，查表可流水共享；不能把算子数直接当复音数。

用户已经选择同时保留两种候选，本轮完成各自单声部实现。后续先试听新RTL、安排实际输入和板卡验证，再设计新音色的多声部调度与资源共享；当前32声部默认核的管理器时序问题仍是另一项未完成任务。
