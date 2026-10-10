# Looper session LU1 接口入口

2026-10-10独立候选，源码及契约纳入本次开发同步；不是SYSTEM_V0/AUDIO_TRANSPORT_V1的隐式替换。

正式本轮地址、字段、单位、时序、ACK/错误及复位定义统一在[UI_CONTRACT](../../project/looper_session_v2/UI_CONTRACT.md)。C从[C_HANDOFF](../../project/looper_session_v2/C_HANDOFF.md)导入session_link、解包器与示例；真实画面/蓝牙后续再整合。

模型验证通过；19针独立板50MHz通过，全接口50/150MHz审计仍有时序违例，具体报告见[VALIDATION](../../project/looper_session_v2/VALIDATION.md)，不能据此宣称整机已通过。
