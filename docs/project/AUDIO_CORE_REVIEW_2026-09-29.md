# 9月29日音频V2验收入口

V1和独立钢琴16/32已获用户认可。本轮新候选在
[audio_core_v2](../../project/audio_core_v2/README.md)，不覆盖旧工程。

打开 `project/audio_core_v2/audio_v2.gprj`，顶层 **audio_v2_top / 19 IO**，
SRAM下载 `project/audio_core_v2/impl/pnr/audio_v2.fs`。
按[上板步骤](../../project/audio_core_v2/BOARD_TEST.md)验收，
固件指纹、资源与数字范围见[验证](../../project/audio_core_v2/VALIDATION.md)。

钢琴/铃音/Lead/custom共享32声部、Warm pluck12，混合总数32。
所有声部保留实例松键和旧尾音；谐波固定每音1/4、拨弦原电平。
控制与V1相同，无须移动现有接线。新固件仍待本轮用户板测。

先听五音色，再查延音下快速连弹、混合旧尾音、满池拒收、止音与恢复，最后查Lead和自定义。
没有二极管的4×4优先顺次弹奏，不用矩形和弦绕过鬼键保护。
本机参考合辑 `project/audio_core_v2/audio/audio_v2_preview.wav`，不作归一化，
主音量65536；实际板卡默认8249，请对齐后比较。

B的25键/双区与5推子规划不变；真实ADC驱动仍未接入。
C接口看[AUDIO_CORE_V2](../interfaces/AUDIO_CORE_V2.md)，预算不变，whole bundle跨域。
完整接口含现有输入仅综合Logic28282，余718，未来驱动要重新核算。
显示/蓝牙/真实ADC未合并，不能把独立数字相加当整机PnR。
