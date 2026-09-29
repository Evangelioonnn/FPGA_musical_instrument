# 接口入口与成熟度

新工作以V2＋接入包为准；不同名称中的V1/V2指各自协议版本，不表示所有带V1文件都已作废。V2明确继承的V1字段仍有效。物理电气、最终控制板、蓝牙线协议和新增按键事件流尚未冻结。

| 当前接口 | 状态 | 入口 |
|---|---|---|
| 音频核心V2 | 32共享槽/12 Warm pluck，能力表/2368bit基础状态＋扩展＋键图 | [AUDIO_CORE_V2](AUDIO_CORE_V2.md) |
| 当前参数单位与基础声部布局 | V2引用V1的单位、参数握手及320bit头/64bit声部；V1原N8总宽不是V2总宽 | [AUDIO_CORE_V1](AUDIO_CORE_V1.md) · [参数服务SPEC](../../project/audio_parameter_lab/SPEC.md) |
| 状态、PCM、命令ACK跨域 | 46字状态、全速PCM、单事务请求，reset/drop/gap已定义 | [AUDIO_TRANSPORT_V1](AUDIO_TRANSPORT_V1.md) |
| 源码导入与无板mock | 精确清单与可运行示例 | [AUDIO_IMPORT_V1](AUDIO_IMPORT_V1.md) · [接入包](../../project/audio_integration/README.md) |
| 显示消费与UI目标 | 接口已有，真实显示/FFT仍待C实现 | [DISPLAY](DISPLAY.md) · [C规划](../team/C_HANDOFF_AND_DISPLAY_PLAN.md) |
| 外部IO/电气 | 待B/C提案、A统一集成；独立彩条映射已有实测 | [IO资源](../board/IO_RESOURCES.md) · [板卡显示](../board/DISPLAY.md) |
| 无线帧/曲谱/LED/逐事件 | 当前未冻结；不可推断接入包已经实现 | [通信入口](../../project/communication/README.md) |

## 历史参考，不作为新消费者默认契约

- [SYSTEM_V0](SYSTEM_V0.md)：历史system的229bit状态/抽取流和配置；不能直接解V2。
- [CONTROL](CONTROL.md)、[EVENTS](EVENTS.md)：旧expression/baseline事件与4bit参数；不是V2的5bit命令/实例身份。
- [MATRIX_PLAYABLE_V1](MATRIX_PLAYABLE_V1.md)、[KNOB_CANDIDATE](KNOB_CANDIDATE.md)：旧矩阵/旋钮独立实验，复用前按工程范围检查。

新增接口须写单位、位宽、时序、握手/复位/溢出和消费者影响。音频/显示/蓝牙整机尚未合并，不能把接口具备写成硬件完成。
