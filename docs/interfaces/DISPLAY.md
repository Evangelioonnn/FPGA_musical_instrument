# 当前显示消费者接口入口

当前使用 **音频V2＋音频接入包**，不再以SYSTEM_V0的229bit快照/48倍未滤波抽样作新开发基线。旧接口全文保存在[历史快照](../history/DISPLAY_INTERFACE_BEFORE_C_HANDOFF_2026-09-29.txt)。

| 要接什么 | 当前文档/模块 | 注意 |
|---|---|---|
| 状态和能力 | [AUDIO_CORE_V2](AUDIO_CORE_V2.md)；V2明确继承的单位/声部布局见[AUDIO_CORE_V1](AUDIO_CORE_V1.md) | 固定ID0/2/3/4/5、32共享槽/12拨弦；读取occupied后才解释声部数据 |
| 完整状态跨域 | [AUDIO_TRANSPORT_V1](AUDIO_TRANSPORT_V1.md)，audio_snapshot_bridge | 46×64bit一致记录，不能逐位同步多位总线；整帧接纳 |
| 精简首屏字段 | audio_state_view | 并非完整解包器；谐波、音区、模式、ADSR等需C扩展解包 |
| DAC前真实PCM | audio_pcm_bridge，signed16 L/R＋sample_index32，Fs=50MHz/1040 | gap后丢弃当前FFT窗口；消费者不反压音频 |
| UI/蓝牙调参 | audio_command_bridge | C先仲裁为一个客户端；ACK为目标提交，不是平滑完成 |
| 无板开工 | [接入包mock与测试](../../project/audio_integration/README.md) | mock不是实物已完成证据 |

约47Hz状态快照可遗漏极短击键；精确练习评分或事件录音需另建可靠带时间戳事件接口。实际键图、声部held/gated/occupied含义不同；Warm pluck包络字段为0不代表无声。干声L=R时XY应为直线，房间效果才可能展开；延迟相图须另命名。

界面布局、旋钮导航、多页方案、比赛覆盖和资源估算统一见[C设计目标](../team/C_HANDOFF_AND_DISPLAY_PLAN.md)。物理TMDS链路、电气与复位看[板卡显示资料](../board/DISPLAY.md)，不是本页定义针位。所有音频状态都走内部逻辑端口，不能展开成数千芯片IO。
