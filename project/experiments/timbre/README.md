# 新音色独立试听：先决定喜欢什么声音

这里的 FM、电拨弦算法是 **Python/浮点离线候选**，没有完成定点 RTL、Gowin综合或上板。不会替换原 instrument 默认音色，也不据此宣称完成“两个乐器音色”指标。

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

建议下一步只选一个喜欢的候选，先做单声部定点RTL与数值对照，再扩展复音。当前32声部默认核已暴露管理器时序瓶颈，新增复杂音色前应先优化分配器与资源共享。
