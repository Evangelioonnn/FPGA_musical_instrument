# 接口入口与成熟度

这里描述已有RTL并列出整机需要补齐的契约。**不是所有接口均已冻结或实现。** 物理引脚、蓝牙线协议、显示跨域接口尤其还未确定。

| 接口 | 状态 | 入口 |
|---|---|---|
| 音频核心V2 | 32共享声部/12 Warm pluck、V2能力表/2368bit基础快照+扩展+键图；19针PnR与全接口输入综合通过，新固件待板测；真实ADC/C/整机PnR仍待接入 | [AUDIO_CORE_V2](AUDIO_CORE_V2.md) |
| 音频核心V1 | 统一五音色配置/ADC模拟接口、真实最终PCM/832bit快照；数字及19针PnR通过，实体ADC/显示CDC/蓝牙整机待集成；不覆盖旧SYSTEM_V0 | [AUDIO_CORE_V1](AUDIO_CORE_V1.md) |
| system v0统一候选 | FIFO/输入路由/配置仲裁/真实快照/CDC已数字验证；真实外设、BLE和显示待集成 | [SYSTEM_V0](SYSTEM_V0.md) |
| 矩阵演奏实例候选 | 32bit独立身份与逐实例松键、三音色真实输入顶层；数字/PnR通过，实物未验收；不替换SYSTEM_V0 | [MATRIX_PLAYABLE_V1](MATRIX_PLAYABLE_V1.md) |
| 旋钮独立实例候选 | 定时弹奏、同音尾音叠加、音色/参数模式；外部逐实例松键与整机协议待集成 | [KNOB_CANDIDATE](KNOB_CANDIDATE.md) |
| 音符事件/声部状态 | expression与baseline已有端口，可作为v0参考；未接真实输入 | [EVENTS](EVENTS.md) |
| 参数握手/能力差异 | 已有控制模块；baseline仅使用部分参数 | [CONTROL](CONTROL.md) |
| 可视化状态/波形 | system有快照/抽取与独立CDC；显示帧缓冲/像素域待C集成 | [DISPLAY](DISPLAY.md) |
| 外部电气与IO | 待B/C提案和A集成 | [IO资源](../board/IO_RESOURCES.md) |
| UART/BLE帧格式 | 尚无冻结协议，由C提案 | [通信入口](../../project/communication/README.md) |

已有候选核心更详细说明见[expression/INTERFACES](../../project/expression/INTERFACES.md)。若其描述与固定试听baseline不同，以本目录能力表和实际RTL为准。协议改动提交版本、前后差异、消费者影响和测试；不让三个人各自发明相似但不兼容的事件格式。
