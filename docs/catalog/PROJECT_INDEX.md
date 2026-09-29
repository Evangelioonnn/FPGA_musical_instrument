# 工程分类索引

> 当前开发只从V2、音频接入包和[C设计目标](../team/C_HANDOFF_AND_DISPLAY_PLAN.md)进入；下表保留旧工程生命周期，不把旧“候选”当成与当前基线并列的新任务。

新增[audio_core_v2](../../project/audio_core_v2/README.md)：`INTEGRATION_CANDIDATE`，固定0/2/3/4/5菜单、32共享逻辑声部/12路Warm pluck物理池，混合总数≤32；谐波固定每音1/4、拨弦原电平。正式入口audio_v2.gprj/audio_v2_top，19针50MHz PnR24052/10684/66/24.5、余量0.632ns；本目录的完整25键+现有输入顶层仅综合审计；后续接入包另有32 IO保留接口PnR审计，见下条，均未合并C/实体ADC。八项数字回归、七段参考音及当前源码核对完成；用户对完整版本总体听感认可，模拟与满载工况仍待测。16拨弦及其他失败架构明确分在experiments，不能下载。用户已认可V1和独立16/32板测，详见[9月29日记录](../../evidence/audio_core_v1_2026-09-29/BOARD_LISTENING.md)。

新增[project/audio_integration](../../project/audio_integration/README.md)：`INTEGRATION_CANDIDATE / TRANSPORT_REFERENCE`，精确20/25源profile、复用真实V2状态寄存器的46字快照、16-bit窄RAM全速立体声PCM FIFO、单事务配置ACK及精简UI解包。三桥测试通过；真实核心联动有旧同RTL指纹PASS，最新新库ModelSim复跑停滞，不计新PASS，详见VALIDATION；保留接口审计PnR为31075 Logic/15790 Reg/64 BSRAM/24.5 DSP、32审计IO、50MHz setup余量0.076ns，无违例/未命中约束。PnR顶层内部模拟ADC/host，不含C UI/FFT/UART/实体ADC，且不能下载；C额度保持26 BSRAM/16 DSP，传输桥按A共享预算记录。packed-bank候选改变Warm pluck PCM，明确拒绝；细节见目录[VALIDATION](../../project/audio_integration/VALIDATION.md)及[最新预算](../team/RESOURCE_BUDGET_V1.md)。

新增[project/audio_core_v1](../../project/audio_core_v1/README.md)：`INTEGRATION_CANDIDATE`，当前0/2/3/4/5五项菜单、八声部、统一参数/ADC模拟输入、ADSR/延音/Lead调制、短房间效果及真实PCM/832bit状态。19针50MHz PnR为24151 Logic/10918 Reg/42 BSRAM/72.5 DSP、setup余量2.562ns；数字验证与非对称立体声串行通过，用户已认可V1主工程音色/效果；模拟SNR/延迟和整机C/ADC仍未验证。入口：[验收](../project/AUDIO_CORE_REVIEW_2026-09-28.md)、[接口](../interfaces/AUDIO_CORE_V1.md)。

新增[project/audio_polyphony_lab](../../project/audio_polyphony_lab/README.md)：`EXPERIMENT / RTL_REFERENCE`，钢琴共享ROM/算子，16/32声部独立模型和50MHz PnR通过，4/10 BSRAM、各2 DSP；安全版每音固定1/2、1/4，不偷音或按活跃数改电平。独立16/32已获用户复音试听认可；该独立工程不含五音色/C，不替代V2整机满载与模拟测量。

新增[project/audio_parameter_lab](../../project/audio_parameter_lab/README.md)：`RTL_REFERENCE`，公平host/local仲裁、sample_ce提交、5路ADC快照、pickup与默认恢复；两项回归通过，实体SPI未接。新增[project/audio_fx_lab](../../project/audio_fx_lab/README.md)：`EXPERIMENT / RTL_REFERENCE`，有界立体声短房间效果和Lead颤音，独立整数模型与50MHz通过，V1主版本已整合且用户总体认可效果；不等于每个独立压力场景已板测。

**9月28日试听与选择记录：** 五音色及四谐波分别调节已获用户听感认可；保留Precision harmonic piano、Warm pluck、Metallic bell、Drive lead、自定义四谐波，原拨弦退出选择名单但保留历史源码。RTL ID依次为0/2/3/4/5；试听时的custom_harmonic_lab仍为六项循环，随后audio_core_v1已改为上述五项菜单。详见[试听记录与编号边界](../../evidence/audio_selection_2026-09-28/BOARD_LISTENING.md)。下列旧名单与生成时“待试听”描述只适用于各自历史工程，当前实现见本页V2及接入包入口，V1保留回退。

本页是 `project/` 下工程的分类入口。分类描述工程当前能承担的用途，不把某个模块的仿真结果扩大成整机验收。具体命令、参数、资源和限制以工程内的 `README.md`、`SPEC.md`、`VALIDATION.md` 及 `docs/project/STATUS.md` 为准。

## 状态标签

| 标签 | 含义 | 使用边界 |
|---|---|---|
| `REUSE_BASELINE` | 已有明确验证结果，可作为后续工程依赖或板测基线 | 仍需检查接口和约束是否适合新顶层 |
| `BOARD_SMOKE` | 已完成单项板级闭环，适合复现硬件链路 | 不代表最终产品功能 |
| `RTL_REFERENCE` | RTL/综合/PnR验证有价值，可复用模块或算法 | 没有相应的真实输入或整机验收时，不能称为成品 |
| `INTEGRATION_CANDIDATE` | 正在向整机汇合，接口和资源仍可能变化 | 只能在任务分支中依赖，合入前要重跑整机验证 |
| `EXPERIMENT` | 独立探索、候选音色、容量或效果器 | 不能替换默认基准，失败结果也要保留边界 |
| `DIAGNOSTIC` | 专门测量或定位问题 | 不作为产品顶层，不把它的顶层约束带入整机 |
| `FUTURE_SKELETON` | 目录和接口准备，实际硬件或协议尚未完成 | 不能描述为已接入 |
| `HISTORY_OR_NEGATIVE` | 历史记录或已知失败边界 | 阅读参考，不作为当前开工入口 |

## 当前工程清单

新增[project/five_timbre_core](../../project/five_timbre_core/README.md)：`EXPERIMENT / RTL_REFERENCE`，原五音色及00/01/02音区对照、选择性延音与Drive lead弯/滑音；已收到用户试听认可，三份差异不明显。其旧名单含原拨弦1，后续产品名单用audio_core_v1的0/2/3/4/5；数字/PnR见[验证记录](../../project/five_timbre_core/VALIDATION.md)，final仍为完整回退。

新增[project/custom_harmonic_lab](../../project/custom_harmonic_lab/README.md)：`EXPERIMENT / RTL_REFERENCE`，六项菜单含preset5、Q8四谐波、CH0后混音音量、EC11模拟推子。6项RTL测试/限幅不变量/PnR见[验证报告](../../project/custom_harmonic_lab/VALIDATION.md)，21330 Logic/9755 Reg/38 BSRAM/70 DSP，50MHz通过；四谐波分别调节已获用户认可，实体SPI ADC与J13未接，当前参数整合候选转入audio_core_v1。

新增[project/timbre_gallery](../../project/timbre_gallery/README.md)：`EXPERIMENT / INTEGRATION_CANDIDATE`，一份可演奏工程在板载S1切换八音色，旧钢琴/拨弦数字等价；六种新声音、按音色适配的控制及Lead滑音通过RTL测试。独立50MHz PnR为19381 Logic、8509 Register、34 BSRAM、52 DSP、19 IO，setup/hold无违例但setup余量仅0.183ns。[试听步骤](../../project/timbre_gallery/BOARD_TEST.md)与[验证边界](../../project/timbre_gallery/VALIDATION.md)；八音色已收到[首轮用户试听反馈](../../evidence/timbre_gallery_2026-09-27/BOARD_LISTENING.md)，不等于全部控制和音质通过；整机显示/蓝牙仍待整合，不能替换已认可的final/00回退基准。

新增[project/audio_output_lab](../../project/audio_output_lab/README.md)：`DIAGNOSTIC / EXPERIMENT`，四份钢琴/柔和拨弦可演奏对照，50MHz PnR均通过，34 BSRAM/50 DSP。检查固定钢琴电平、串行边沿和极性相关性；不替代palette/final，不标记杂音修复；[数字与实现证据](../../project/audio_output_lab/VALIDATION.md)，首轮用户反馈整体起音/颤动改善但仍有杂音，02/03与00无差别，用户补充00最大音量下颤动仍明显改善，原因待定位；详见[板测记录](../../evidence/audio_output_lab_2026-09-27/BOARD_LISTENING.md)。

| 工程 | 标签 | 已有证据 | 后续使用方式 |
|---|---|---|---|
| [project/audio_palette_lab](../../project/audio_palette_lab/README.md) | `EXPERIMENT` | 七份八声部双区音色候选全部50MHz PnR通过，22–34 BSRAM/50–51 DSP；共享原版4582帧逐样本等价；25键映射/同音身份/49音域/串行输出数字验证 | 01–06首轮试听：01/05/06音色获肯定，01–04有高电平异常（01伴随颤动，无独立起音问题），原尖锐声仍在；共享表/双区为候选复用，未覆盖已板测final/扩复音/加效果器 |
| `project/instrument` | `REUSE_BASELINE` | 原正弦DDS、ADSR、PT8211的RTL、PnR和用户基础试听 | 历史默认音色和音频发送器来源；板卡尖锐附加声仍未解决 |
| `project/audio_probe` | `BOARD_SMOKE` | PT8211左右输出和基础时序的用户板测 | 新顶层验证音频物理链路时复用 |
| `project/test` | `BOARD_SMOKE` | T18驱动PMOD-LEDx8的用户板测 | PMOD/下载最小烟雾测试，不是产品功能 |
| `project/input/ec11_probe` | `BOARD_SMOKE` | A=T18、B=R17，3.3V供电，用户确认双向、快慢旋转、每格一音、静止稳定 | EC11输入复现和整机接入前回归；C脚/按压未定义 |
| `project/input/knob_suite` | `INTEGRATION_CANDIDATE` | 五种控制固件；首次板测认可音量/释放与基础弹奏，数字/启动相位检查通过 | 快转起音/转动切换音色有新增杂音；按压未绑定，定时接口还需扩展成正式按键接口 |
| `project/input/matrix_playable` | `INTEGRATION_CANDIDATE` | 八声部三音色输入顶层、数字验证及50MHz PnR；用户反馈除原有杂音外功能良好 | 保留旧三音色控制参考；当前产品音频入口为V2五音色，音质根因未定；不推断灯色已逐项验收 |
| `project/input/src` | `RTL_REFERENCE` | 矩阵、EC11、键路由和数字压力模块独立仿真 | 接入最终外部电气前，先遵守接口和电压边界 |
| `project/polyphony` | `RTL_REFERENCE` | 四声部管理、混音、串行和构建验证 | 复音结构参考；合并真实输入后需重做资源/板测 |
| `project/system` | `RTL_REFERENCE` | 输入适配、配置仲裁、快照和音频系统数字验证 | 历史整机候选；system_top仍是自动演示，新集成使用V2接入包 |
| `project/expression_baseline` | `INTEGRATION_CANDIDATE` | 原音色复用、力度/音量/延音和复音电脑演示 | 默认功能回归候选；板上尖锐声和真实交互仍是限制 |
| `project/expression` | `INTEGRATION_CANDIDATE` | 表情、效果和状态接口的数字验证 | 只按共享契约逐项接入，不把旧顶层当最终顶层 |
| `project/experiments/capacity16` | `RTL_REFERENCE` | 16声部资源与50MHz实现通过 | 作为复音容量参考，合入整机必须重新实现 |
| `project/experiments/capacity32` | `HISTORY_OR_NEGATIVE` | 资源可放下，但50MHz时序未通过 | 只记录失败边界，不作为达标固件 |
| `project/experiments/delay` | `EXPERIMENT` | 短反馈延迟的独立RTL和数值证据 | 效果器候选，尚未接入system |
| `project/experiments/timbre` | `EXPERIMENT` | FM/拨弦独立RTL、PnR和用户试听 | 新音色候选；FM/拨弦杂音与整机切换仍未解决 |
| `project/audio_quality` | `DIAGNOSTIC` | 数字精度、长音和监听参考分析 | 继续定位耳机尖锐声，不作为产品音色工程 |
| `project/audio_noise_lab` | `DIAGNOSTIC` | 五个输出链软件对照通过RTL/PnR；基准、数字增益×2/×4、PT8211帧率×2/×4；用户已完成首轮试听 | 五版均仍有噪声；增益只改变响度，过采样未听出实质改善；示波器未做；activity-gate RTL等价但PnR有336条未布线，不能下载 |
| `project/audio_clean_lab` | `EXPERIMENT` | 四个矩阵复用音色候选通过RTL/PnR并完成用户首轮板测；`harmonic_piano` 主观最佳，`triangle` 最干净但偏数字化 | harmonic_piano已用于final双音色；其余保留实验，公共噪声根因仍待定位 |
| `project/resource_optimization_lab` | `EXPERIMENT` | 正弦-only 下限、共享 ROM/乘法探针和完整八声部共享正弦候选；完整候选 `3894 Logic / 2277 Register / 1 BSRAM / 2 DSP`，624帧逐样本对照0 mismatch，50 MHz PnR通过 | 只覆盖默认正弦，未板测；FM/拨弦共享和三音色整机迁移未完成 |
| `project/final_dual_timbre` | `REUSE_BASELINE` | harmonic_piano/pluck、矩阵、EC11、三板载键、八声部RTL回归；`12723 Logic / 5459 Register / 80 BSRAM / 57 DSP / 19 IO`，50MHz PnR通过，用户已板测认可 | 音频方向第一版完整演示；未整合显示/蓝牙，噪声根因未查明；优化在新候选验证 |
| `project/audio_format` | `DIAGNOSTIC` | PT8211格式A/B排查 | 只有新测量支持时才修改发送器 |
| `project/lab` | `DIAGNOSTIC` | C4/A4/静音长音测试顶层 | 板卡实验室测量入口，不作为最终顶层 |
| `project/input/input_audit.gprj` | `DIAGNOSTIC` | 输入逻辑资源综合审计 | 316逻辑端口，不能下载，不能当板级顶层 |
| `project/communication` | `FUTURE_SKELETON` | 蓝牙方向和接口说明 | C负责协议/客户端评估，硬件和RTL尚未接入 |
| `project/visual` | `INTEGRATION_CANDIDATE` | 已有独立彩条及显示接口说明 | C按团队预算加入真实状态/波形/FFT与CDC，尚未整合音频 |
| `project/visual/dvi_colorbar_probe` | `BOARD_SMOKE` | 独立1920×1080 TMDS彩条，综合/PnR通过；用户普通HDMI显示器稳定显示1080p、61Hz；映射J14/H14、J15/H15、K17/J17、G15/G16 | C物理链路复现起点；统一Y12用途及Bank5电气属性后再合并，不代表实时可视化已完成 |

## 复用前的最小检查

1. 先读目标工程 README、SPEC 和 VALIDATION，确认它的顶层名称。
2. 确认本次输入/音频/显示的 IO 与 Bank 电压没有冲突。
3. 不复制旧 `impl/`、`.fs` 或 Designer 用户配置作为源码依赖；使用工程自己的 `build.tcl` 重建。
4. 将仿真、综合/PnR、板测和用户验收分别记录，不能用上一层证据替代下一层。

## 根目录 Markdown 的处理

根目录只保留两个真正的长期入口：`README.md` 和 `AGENTS.md`。其他根目录 Markdown 目前分为两类：

- 兼容入口：`AUDIO_TEST_BASELINE.md`、`DEVELOPMENT_METHOD.md`、`MEETING_BRIEF_2026-09-18.md`、`EXECUTION_ROADMAP.md`、`OVERNIGHT_REVIEW.md`、`PROJECT_CONTEXT.md`、`RESOURCE_IP_PRODUCT_PLAN.md`、`SYNTHESIS_PLAN.md`、`TEAM_WORKFLOW.md`、`TIMBRE_PLAN.md`。它们现在只负责把旧链接指向 `docs/project`、`docs/team` 或 `docs/history`，不应继续在根目录编辑。
- 当前正文：`docs/project/AUDIO_TEST_BASELINE.md` 和 `docs/team/DEVELOPMENT_METHOD.md`。规范、流程和结论以后只在这两个新位置维护。

`Notification/` 是本机下载资料，不是仓库当前事实入口；官方资料的精选版本和来源索引在 `references/`。
