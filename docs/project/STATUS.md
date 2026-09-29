# 当前状态 · 2026-09-29

本页只保留当前事实和待办。逐轮实验、旧“待板测”和旧推送失败记录已保存为[历史快照](../history/STATUS_BEFORE_C_HANDOFF_2026-09-29.txt)；不能覆盖本页或用户的新决定。

## GitHub与开工入口

当前交接分支 **`codex/audio-integration-pack`**，音频/接入代码基线 `e500e30`，后续为本轮C规划和文档整理。已拉取远端核实：`main`仍停在首次交接`4ada74e`，最新音频、显示探针、资料及接入包在交接分支，尚未通过PR合并到main。不要仅拉main后照旧说明开工。

- C先读[交接与显示设计目标](../team/C_HANDOFF_AND_DISPLAY_PLAN.md)和[ROLE_C](../team/ROLE_C.md)，再用[接入包](../../project/audio_integration/README.md)开发。
- B先读[ROLE_B](../team/ROLE_B.md)、[J13针表](../board/J13_GPIO.md)和[唯一团队预算](../team/RESOURCE_BUDGET_V1.md)。A与B共同规划成品控制板。
- 音频复现：[audio_core_v2](../../project/audio_core_v2/README.md)；A后续总集成：[ROLE_A](../team/ROLE_A.md)。
- 正式指标：[REQUIREMENTS](REQUIREMENTS.md)；工程复用/历史范围：[PROJECT_INDEX](../catalog/PROJECT_INDEX.md)；协作：[WORKFLOW](../team/WORKFLOW.md)。

## 当前实物与音频

板卡为Tang Mega 60K基础套餐＋NEO Dock，工程GW5AT-60B / GW5AT-LV60PG484AC1/I0；DK_START及138K资料不等于本板。当前实物输入为4×4无二极管矩阵、EC11及三板载键；EC11 A=T18/B=R17、3.3V、C悬空，按压未确认。成品按总两八度、双区独立移八度规划，25键逻辑适配已具备，实体PCB尚未完成。

当前五音色ID固定为 **0钢琴、2 Warm pluck、3 Metallic bell、4 Drive lead、5可编辑四谐波**，ID1旧拨弦退出菜单但保留历史源码。V2中0/3/4/5共享32逻辑槽，Warm pluck物理池12，混合和尾音总数≤32；满载拒收新击键、不偷音、不按活跃数归一化。谐波每音固定V1的1/4，拨弦原电平，不能描述成全音色与V1同电平。

已有音量、双区八度、普通/选择性延音、释放、ADSR覆盖、Lead滑入/弯音/颤音、可旁路短房间效果及四谐波持续音平滑编辑。Warm pluck自然衰减，不强行套用延音/释放。五推子计划由同颗8通道12bit SPI ADC采集：CH0后混音主音量、CH1～4谐波；实体ADC尚未接入。参数服务统一本地/host/ADC模拟输入，包含pickup。

用户已认可[V1及独立钢琴16/32](../../evidence/audio_core_v1_2026-09-29/BOARD_LISTENING.md)，并对[V2完整版本](../../evidence/audio_core_v2_2026-09-29/BOARD_LISTENING.md)表示总体听感认可。这不是满载32/12实物、模拟SNR/延迟或音频显示整机验收。旧尖锐伴音根因仍未定位，不能写为全部修复；也不应用旧FM等失败候选的听感否定现有五音色反馈。

## 验证与资源

| 对象 | 已有结果 | 边界 |
|---|---|---|
| V2数字 | 八项回归、七段RTL参考音、32个不同音高独立相位对照；最坏渲染653/1040时钟 | Fs=50MHz/1040；四谐波不直接乘四当独立振荡器 |
| 实际矩阵数字延迟 | 四种闭合相位到首个非零PT8211串行字，最坏2.12198ms | 仿真数字延迟，不是输入到模拟输出延迟，也不证明无抖动 |
| V2可下载音频顶层 | `audio_v2.gprj / audio_v2_top / 19 IO`；PnR 24052 Logic / 10684 Reg / 66 BSRAM / 24.5 DSP，50MHz setup/hold 0/0，余量0.632ns | 既有物理输入及音频；不含实体ADC/C |
| 保留接口审计 | 31075 Logic / 15790 Reg / 64 BSRAM / 24.5 DSP，32审计IO；50MHz setup/hold 0/0，余量0.076ns，约束未命中0 | ADC/host为内部激励；不可下载，不含C显示/FFT/UART/蓝牙或最终PCB |
| 接入包 | 20源核心/25源集成清单；完整46字状态、全速PCM、命令ACK桥、精简解包/mock；三桥及干净导入/消费者检查通过 | 完整核心联动有旧同RTL指纹PASS；本轮新仿真库重跑在ModelSim停滞，终止且不计新PASS |
| packed bank优化 | Warm pluck第1274帧候选133、参考164，PCM不等价 | 已拒绝，默认仍用 `audio_v2_bank_stream.v` |

精确证据见[V2验证](../../project/audio_core_v2/VALIDATION.md)和[接入包验证](../../project/audio_integration/VALIDATION.md)。C预留 **13000 Logic / 10000 Register / 26 BSRAM / 16 DSP / 1 PLL** 不变；保留接口审计Logic超过A+输入29k目标2075，按[预算](../team/RESOURCE_BUDGET_V1.md)由A处理，不侵占C额度。容量规划不是整机PnR，0.076ns余量尤其需要后续收敛。

## 显示、通信与控制板

- 独立[TMDS彩条](../../project/visual/dvi_colorbar_probe/README.md)已实测普通HDMI显示器1920×1080、约61Hz；用J14/H14、J15/H15、K17/J17、G15/G16。无HDMI音频/触摸/EDID自动协商；统一Y12用途、Bank5电气和所有时钟约束后才可合并，见[DISPLAY](../board/DISPLAY.md)。
- C的真实UI、FFT、蓝牙、脱机曲谱/LED尚未实现；新[设计目标](../team/C_HANDOFF_AND_DISPLAY_PLAN.md)是规划，不是已有功能。精确按键事件、任意逐键映射、未接管推子原始位置等另需接口适配。
- B可用J13 36根直接候选信号，另2根电阻选择待核；加PMOD共52根直接候选。J13逐针实物未测，旧PMOD外设仍接着就仍占用；不能重复计数。
- 屏幕导航可由新增带独立按压编码器或三键实现，暂未选型/采购/分针。C先模拟导航事件；A/B安排实物与输入适配。

## 下一步

1. B/C从交接分支各建工作分支；C首批交屏幕草图、mock渲染、协议/资源和缺口表，B交操控布局、电气和IO提案。
2. A/C尽早做“现有音频＋少量真实状态屏”最小合并，先处理电气/复位/CDC与时序，再加FFT/蓝牙。
3. 逐批接实体ADC、控制板、真实LED、显示/通信；每次重新整机PnR、故障恢复和音频期限验证。
4. 实测模拟端延迟、音质/SNR、多维操控与官方拓展项，保留可回退音频固件。采购、投板、Flash、正式比赛发布和队友消息不由文档规划自动触发。
