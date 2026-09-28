# 9月28日验收入口

本轮在 `codex/audio-core-v1` 本地任务分支完成，旧已板测工程不覆盖。
先验收八声部完整音频版本，再单独听16/32声部钢琴；它们是不同固件，不在一份工程里切32模式。

## 1. 五音色主版本

Designer工程：`project/audio_core_v1/audio_core.gprj`。
Top Module/Entity：`audio_top`，19 IO。
SRAM下载：`project/audio_core_v1/impl/pnr/audio_core.fs`。

操作详见[BOARD_TEST](../../project/audio_core_v1/BOARD_TEST.md)。
S1短按依次钢琴、Warm pluck、铃音、Drive lead、自定义四谐波；旧原拨弦已移出菜单，ID不重编号。
S2短按普通延音，长按选择性延音；S4短按模式，长按止音；S1长按恢复默认。
第一次先检查默认声音、音量/八度/释放，再试滑音/弯音、颤音、房间效果和ADSR。
完整菜单较多，模式计数与适用音色看指南，不把一种音色的控制强加给拨弦。

数字参考：[五音色与房间/颤音](../../evidence/audio/audio_core_v1_2026-09-28.wav)。
顺序为0/2/3/4/5，每段约0.50秒，最后是Lead加房间/颤音；没有归一化。
各段独立复位后生成再拼接，提供声音和立体声算法参考，不替代连续切换、真实演奏和模拟监听。

主版本实测42 BSRAM/72.5 DSP，50MHz最小setup余量2.562ns，无setup/hold违例。
详细[验证记录](../../project/audio_core_v1/VALIDATION.md)及[本轮证据](../../evidence/audio_core_v1_2026-09-28/README.md)。

## 2. 钢琴高复音

| 版本 | Designer工程 | SRAM下载 | 固定每音电平 |
|---|---|---|---|
| 16声部 | `project/audio_polyphony_lab/variants/piano16/piano16.gprj`，top piano16_top | 同目录 `impl/pnr/piano16.fs` | 旧8声部的1/2 |
| 32声部 | `project/audio_polyphony_lab/variants/piano32/piano32.gprj`，top piano32_top | 同目录 `impl/pnr/piano32.fs` | 旧8声部的1/4 |

两个版本用同一副矩阵/旋钮。控制有区别：底板S1短按止音；音色固定钢琴，不是切音色。
验收普通/选择性延音、两区同音和连续叠加，分别试17/33次击键，检查满载拒收不偷旧音。
无二极管矩阵不能任意同时按16键，满载通过延音后顺次击键累积即可。
步骤和固件指纹见[高复音BOARD_TEST](../../project/audio_polyphony_lab/BOARD_TEST.md)。
参考： [8声部原电平](../../evidence/audio/piano8_audio_core_v1_2026-09-28.wav)、
[16声部固定减半](../../evidence/audio/piano16_audio_core_v1_2026-09-28.wav)、
[32声部固定四分之一](../../evidence/audio/piano32_audio_core_v1_2026-09-28.wav)。
不得因32版较轻声就认为每次新音让旧音变小；固定缩放从第一声起就存在。

## 3. 交接与剩余工作

B可据[音频接口V1](../interfaces/AUDIO_CORE_V1.md)继续设计25键双区与5推子控制板。
现有主版本已预留配置/ADC逻辑接口，但没有猜测实体ADC型号/SPI模式或挪动J13接线。
C可用实际PCM和832bit声部/电平快照做mock，后续由A适配至C的像素域/蓝牙协议。
旧SYSTEM_V0不用重新定义，不能把新832bit头直接当旧格式。

三份音频构建各自通过，不代表音频+显示+蓝牙全部时序通过。
Bank5和Y12整合、实体ADC、模拟延迟及噪声仍独立验证；已板测final保持回退。
收到本轮试听反馈后，可冻结音频基准，让A/B转入控制板设计，仅对实际接入适配作局部修改。
