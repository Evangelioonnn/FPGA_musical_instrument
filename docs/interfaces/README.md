# 接口入口与成熟度

这里描述已有RTL并列出整机需要补齐的契约。**不是所有接口均已冻结或实现。** 物理引脚、蓝牙线协议、显示跨域接口尤其还未确定。

| 接口 | 状态 | 入口 |
|---|---|---|
| 音符事件/声部状态 | expression与baseline已有端口，可作为v0参考；未接真实输入 | [EVENTS](EVENTS.md) |
| 参数握手/能力差异 | 已有控制模块；baseline仅使用部分参数 | [CONTROL](CONTROL.md) |
| 可视化状态/波形 | 现有可读线网；整机快照/CDC/波形缓冲待设计 | [DISPLAY](DISPLAY.md) |
| 外部电气与IO | 待B/C提案和A集成 | [IO资源](../board/IO_RESOURCES.md) |
| UART/BLE帧格式 | 尚无冻结协议，由C提案 | [通信入口](../../project/communication/README.md) |

已有候选核心更详细说明见[expression/INTERFACES](../../project/expression/INTERFACES.md)。若其描述与固定试听baseline不同，以本目录能力表和实际RTL为准。协议改动提交版本、前后差异、消费者影响和测试；不让三个人各自发明相似但不兼容的事件格式。
