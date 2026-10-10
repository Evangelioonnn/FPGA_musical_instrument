# 当前状态 · 2026-10-10

本次开发同步补齐音频／Looper及当前控制板资料，范围见[GITHUB_SYNC_2026-10-10](GITHUB_SYNC_2026-10-10.md)。最新试听和C接口入口为looper_session_v2；下方按日期保留的旧“本地／未push／待板测”是当轮历史状态，不能覆盖最新入口。

## 2026-10-10 Looper session V2：鼓组修订与C接口

用户授权新候选[looper_session_v2](../../project/looper_session_v2/README.md)，直接位于原D盘project目录；保留旧Looper/refinement/V2。按10月9日反馈重排底鼓、四筒、开闭踩镲与更亮长尾吊镲，去除指定旧鼓；五旋律ID及32/12旋律、另8鼓、2048事件不减。

[C交接](../../project/looper_session_v2/C_HANDOFF.md)增加addr8直接动作与held tagged ACK，以及23字LU1窄快照、解包/字段示例/mock和真实PCM跨域。默认关闭完整LR1声部快照，可显式启用并另预算。用户要求本轮先交接口，**C真实屏幕/蓝牙不在本轮接入**；4×4/EC11/3板载键仍是下载版输入，新6×6控制板另做适配。

独立19针50MHz/20ns PnR **33676 Logic /17123 Register /23771 CLS /75 BSRAM /32.5 DSP**，setup/hold0/0，余量**1.117ns**。实际鼓组PCM、命令/CDC/生命周期、回归与参考音的最终范围、接口保留审计及当前指纹，统一见新lab[VALIDATION](../../project/looper_session_v2/VALIDATION.md)。C原预留保持，独立板资格不替代接口/整机时序。本轮来源延用共享工作区；2026-10-10开发同步通过独立任务提交补齐源码和文档，见本页同步说明。

## 2026-10-09 首轮Looper实物反馈

用户认可原有五音色；基本循环未听出明显缺音，开始/停止/恢复正常，停止后自然尾音、无无限卡音。鼓组需要按新的底鼓/四筒/开闭踩镲方案调整。撤销、清轨、分轨混音、表达与自定义因无显示盲操困难尚未充分验收，不能记为全部通过。用户报告显示已能识别按键并映射到屏幕；尚未核对固定源码或完成Looper联合状态接入。详见[本轮反馈与鼓组修改目标](../../evidence/looper_refinement_2026-10-08/BOARD_LISTENING_2026-10-09.md)。以下此前“待板测”按历史范围理解；本轮不修改固件。

## 2026-10-09 软件收敛与统一待验收入口

用户授权完成无需板测反馈的工作，并统一明日验收。新分支`codex/looper-convergence-20261009`固定比较`9d28244`，
在[新lab](../../project/looper_convergence_lab/README.md)验证向零截断/共享乘积寄存、54字快照分级复制、
12个实际物理拨弦复位约束和循环事件ready寄存。没有改动原Looper、refinement或已认可V2。

最终19针50MHz/20ns PnR33722 Logic /17592 Register /23796 CLS /75 BSRAM /31.5 DSP，setup/hold0/0，
余量0.009ns；相对refinement增加256Logic/517Reg/123CLS，RAM/DSP没有改善。**新候选不晋升，明日主验收仍是10月8日改进版。**
数字/接口/参考音完整范围见其[VALIDATION](../../project/looper_convergence_lab/VALIDATION.md)；
[总验收指南](LOOPER_TOTAL_ACCEPTANCE_2026-10-09.md)和[统一包清单](../../project/looper_convergence_lab/results/ACCEPTANCE_PACKAGE.json)
合并此前两轮未验收操作，保留新实验对照、原Looper和V2回退。本轮只本地提交，没有远端push。

不因局部LUT优化或独立50MHz通过承诺整机可放下；C预留保持，仍须真实C源码/PLL/CDC/电气及联合PnR。
当前优先已有功能板测与最小集成，不加40旋律槽或tap/细分点击。下面10月8日/7日为冻结比较范围。

最终42项必测＋2预览＋PLL wrapper模型、9份PCM/WAV回读通过；9段参考与冻结refinement逐字节相同。
实际PLL接口审计2172未布网（42303Logic/23548Reg/26342CLS/79RAM/31.5DSP/1PLLA），无合格STA/FS。
完整collector拒绝，显式BOARD_DELIVERY只授予独立板资格，当前106个LF源指纹核对；4FS/9WAV包内SHA全部通过。
主验收固件与102个旧源指纹、FS、9 WAV保持原样。实体ADC/25键/C整机及模拟验收仍未完成。

## 2026-10-08 第二轮独立改进结果

[looper_refinement_lab](../../project/looper_refinement_lab/README.md)位于本地codex/looper-refinement-20261007，比较起点0199ed7。保留32共享旋律/12拨弦、另8鼓及2048事件，新增每层普通/选择性延音和有界弯音录放、空录/溢出恢复、真实MCP3208/五推子模式pickup模型、25键逻辑生命周期及LR1状态/PCM/ACK跨域接入。实体ADC/25键和C最新UI未并入；C先前独立显示进展以她的分支/板测为准，本机未取得固定源码，不能从本审计推断她尚未实现或整机已完成。

19针50MHz PnR为33466Logic/17075Reg/23673CLS/75BSRAM/31.5DSP，setup/hold0/0，20ns余量0.018ns；相对旧Looper净省11RAM/2DSP，Logic与CLS增加。18ns额外guard失败，不混作通过证据。40项必测、2预览、PLL wrapper行为模型和9 WAV当前源通过；四次接口物理审计均失败，最后26IO/PLL拓扑失败3402网、放置41005Logic/22760Reg/26449CLS/79RAM/31.5DSP/1PLLA，未获得接口STA/可用FS。

严格完整collect已拒绝该失败；最终 [BOARD_DELIVERY](../../project/looper_refinement_lab/results/BOARD_DELIVERY.json)只授予独立板候选资格，不是接口或整机通过。40槽和tap/细分延后，保住C预留并优先整合，详见[逐项计划](../../project/looper_refinement_lab/WORK_PLAN.md)和[预算](../team/RESOURCE_BUDGET_V1.md)。板测待用户；本轮只提交本地，未推送GitHub。后续先验收现有硬件操作，再取得C固定源码优化共享状态访问、快照和复位/布线后做最小整机。

下文Looper为固定旧比较，9月29日V2继续是已认可回退，不用本实验继承其板测资格。

## 2026-10-07独立Looper候选更新

[looper_lab](../../project/looper_lab/README.md)已提供四轨×四层事件循环、五音色与16鼓pad、全局40～240 BPM节拍器及现有矩阵/EC11/三键操作。最新完整19针PnR：32251 Logic/16254 Reg/22780 CLS/86 BSRAM/33.5 DSP，18ns约束setup/hold 0/0、余量0.029ns，实物主时钟仍50MHz。数字范围与源指纹按[验证页](../../project/looper_lab/VALIDATION.md)核对，实体听感和操作验收待用户，未替代音频V2或整合C/真实ADC。

本候选位于 `codex/looper-drum-night-20261007`，不把此分支的实验资格写成main成品发布。C的预留未减少，但BSRAM标量合计只剩6块，CLS也需共同检查，详见[更新预算](../team/RESOURCE_BUDGET_V1.md)。以下9月29日内容继续描述原基线，不覆盖后来独立实验/C分支的进度。



> **控制板更新 · 2026-10-09：** KEYBOARD_V2已完成10月8日R3静态审查，用户报告DRC通过，当前源文件指纹一致。25演奏键＋11功能键、三编码器、五推子、双轴摇杆、25 RGB＋四状态灯；本版不加踏板，实际30根信号IO。版本、真实针序、反贴方向和未验证事项统一见[控制板当前状态](../../hardware/interaction/BOARD_CURRENT.md)。用户已明确确认下单，尚无到货/实物通过反馈，资料尚在本地未推送；双触点力度仅作独立小样探索，不合并到已下单板。以下9月29日音频及团队状态按其日期理解，“实体PCB尚未完成”等旧描述不覆盖本次控制板更新。

本页只保留当前事实和待办。逐轮实验、旧“待板测”和旧推送失败记录已保存为[历史快照](../history/STATUS_BEFORE_C_HANDOFF_2026-09-29.txt)；不能覆盖本页或用户的新决定。

## GitHub与开工入口

当前统一开发与交接基线为 **`main`**。本轮汇总PR将此前`codex/audio-integration-pack`的完整成果及更新说明合入main，源起点`156f12f`；音频/传输代码基线为`e500e30`，本轮没有修改RTL或硬件约束。新成员直接从最新main创建自己的任务分支；此前已从交接分支开发的成员合并origin/main即可。范围与检查见[汇总任务](MAIN_HANDOFF_INTEGRATION_2026-09-29.md)；仅更新首页的旧阶段见[历史记录](HOMEPAGE_REFRESH_2026-09-29.md)。

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

1. B/C从最新main各建工作分支，已有任务分支合并origin/main；C首批交屏幕草图、mock渲染、协议/资源和缺口表，B交操控布局、电气和IO提案。
2. A/C尽早做“现有音频＋少量真实状态屏”最小合并，先处理电气/复位/CDC与时序，再加FFT/蓝牙。
3. 逐批接实体ADC、控制板、真实LED、显示/通信；每次重新整机PnR、故障恢复和音频期限验证。
4. 实测模拟端延迟、音质/SNR、多维操控与官方拓展项，保留可回退音频固件。采购、投板、Flash、正式比赛发布和队友消息不由文档规划自动触发。
