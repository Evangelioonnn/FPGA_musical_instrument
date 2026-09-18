> 历史归档：2026-09-19从工作区保存；保留当时判断及变更顺序。本文的旧进度、旧建议和指令不覆盖[当前状态](../project/STATUS.md)、[正式分工](../team/WORKFLOW.md)或新的用户决定。旧生成产物/Notification路径仅是记录，需按脚本再生成或查references。

# 音色偏好、开源参考与下一步

2026-09-18。来源：用户对 expression 电脑仿真音频的试听反馈，以及本日读取的上游项目说明/源码/许可。下列新音色是建议，尚未实现或移植。

## 已确认的偏好与必须保留的基准

用户反馈：本批次各项效果听起来都还可以，具体音色仍需选择；尤其喜欢此前“电脑仿真正常、上板有尖锐声”的原单声部音色，要求保留。

最新明确要求：**后续功能测试统一使用该原始音色和包络效果**，仅改变当前待测参数；新音色另行筛选。统一基准、原始参数与电平对照规则见 `AUDIO_TEST_BASELINE.md`，不是只保留一份原音色文件。

- 原始基准为 `project/instrument/src/synth_voice.v` 的数学正弦 DDS + ADSR；原试听为 `project/instrument/sim/demo_simulated.wav`。它不是 audio_probe 的 440 Hz 方波。
- 原包络：attack_step=68、decay_step=6、sustain_level=32768、release_step=3；采样率为 50 MHz / 1040。
- 原源码、原 WAV 和原诊断比特流继续保留。expression 的 timbre=0 仍是纯正弦，默认 ADSR 同上述值；因多声部混音、力度和量化路径不同，不声称其输出码值与原单声部逐点相同。
- 后续音色库保留可选的柔和纯正弦预置，不以新音色替换它。新算法应接入现有音符/表情接口；增加参数前另写规格。
- 后续首轮板测：音量静音、力度与八音和弦获主观认可，普通延音有较大噪声，选择性延音有短促突音；原尖锐声在本次条件下未复现，不能称为修复。细节见 `project/expression/reviews/FIRST_BOARD_REVIEW.md`。
- 用户明确不以 expression 的现有三个谐波配方作为最终音色库，原 instrument 音色继续保留；滑音/弯音是否成为产品交互待定，已实现能力保留以供选择。后续音色对比改为相同短旋律分别演示，不只在持续单音上换谐波。

## 核对过的开源参考

| 项目与本次读取来源 | 可以参考什么 | 与本工程的关系 |
|---|---|---|
| [STK](https://github.com/thestk/stk)，[Plucked.cpp](https://github.com/thestk/stk/blob/master/src/Plucked.cpp)，[LICENSE](https://github.com/thestk/stk/blob/master/LICENSE) | Karplus–Strong 拨弦：噪声激励、延迟线、反馈滤波、音高补偿、松键衰减 | C++ 算法参考；需定点化和 HDL 调度，不能直接导入 Gowin。许可允许使用/修改/分发，需保留版权与许可文本 |
| [Mutable Instruments Plaits](https://github.com/pichenettes/eurorack/tree/master/plaits)，[string_engine.cc](https://github.com/pichenettes/eurorack/blob/master/plaits/dsp/engine/string_engine.cc) | 弦音色引擎组织，触发/力度与音色参数的映射 | 本次所读文件为 MIT 许可，属于 C++ 浮点合成代码；可借鉴算法和交互。移植时逐文件核对依赖和许可，不能把整个 eurorack 仓库当作同一种许可 |
| [OPL3 FPGA](https://github.com/gtaylormb/opl3_fpga)，[README](https://github.com/gtaylormb/opl3_fpga/blob/master/README.md)，[许可证入口](https://api.github.com/repos/gtaylormb/opl3_fpga/license) | SystemVerilog FM 合成器；算子时分复用、包络、对数正弦/指数表减少乘法资源 | 上游目标包含 ZYBO/MiSTer，不能照搬时钟、DAC 和约束；README 混有旧版平台描述。许可为 LGPL-3.0。上游 LUT/BRAM 报告不是 Mega60K 资源预测，尚未做 Gowin 兼容性试编译 |

核查范围：STK 的 README/Plucked.cpp/LICENSE、Plaits 的 string_engine.cc、OPL3 的 README/实际许可证。未下载完整仓库，未将第三方代码并入 RTL，未宣称任何候选已在本板运行。

## 推荐音色顺序

1. **柔和纯正弦**：作为已获用户认可的保留音色和诊断基准。
2. **FM 电钢琴 / 钟铃**：推荐下一项算法实验。从两个算子的相位调制、独立衰减包络与随力度变化的调制深度开始；先做好一种可听的预置，再决定是否需要更多算子。目标是有辨识度的电钢琴/钟铃风格，不承诺与原声钢琴或特定商品音源一致。
3. **拨弦音色**：比较简化 Karplus–Strong 与当前谐波包络。真正建模需要处理分数延迟调音、反馈稳定性、低音延迟存储、重触发和松键阻尼；利用 BSRAM 有意义，但实际资源必须综合后再算。
4. **持续管乐风格**：先比较少量谐波、气声、起音过程和表情映射，再决定是否需要完整波导模型。吹嘴传感器与音色算法可分别推进；目前没有吹气输入硬件。

我方可自行实现小型 FM/拨弦候选，再用开源算法和参考音频作对照。是否好听由用户试听决定，既不以“开源成熟”代替板测，也不以模型能力代替音色验收。

按现有题目要求保持 HDL 实时合成通路；不将 SoundFont、预录乐器 PCM 或整段录音播放作为替代。引用或改写第三方实现时记录版本、来源、改动和许可。

## 接下来的实际顺序

1. expression 自动演示已完成首轮板上试听；先把选择性延音第二音与最后释放分开定位，并做同音/同电平的新旧对照。记录见 `project/expression/BOARD_TRYOUT.md`。
2. 然后做最小手动输入：核对可触及的板载用户按键，通过同步/去抖转换成事件，让自动音符与手动参数控制组合起来。当前比特流尚不读取按键。
3. 20 日器件到货后，先验收矩阵/编码器输入，再替换自动音符事件；最终布局继续开放。
4. 原单声部杂音按既有诊断工程去实验室测量；与上述控制验证并行。
5. 下一轮音色实验先生成等主观响度的对照试听，覆盖低/中/高音、单音与和弦、不同力度和延音。选择预置后再增加 FPGA 内核，不一次接入多个大型第三方工程。

当前 expression 已用 49/118 个 DSP 等效资源，扩展 FM/复音/效果器前要重新分配预算；优先评估算子或乘法器时分复用，并证明每个音频采样的运算期限。不能把算子数、谐波数当成独立复音数。
