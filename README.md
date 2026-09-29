# FPGA 实时电子乐器 · 团队仓库

2026 嵌赛高云 FPGA 赛道选题二。板卡：**Tang Mega 60K 基础套餐＋Tang Mega NEO Dock**。三人团队，目标在11月前完成可演奏、可测量、可复现的作品。

## 当前入口 · 2026-09-29

**最新工程与交接资料在 [`codex/audio-integration-pack`](https://github.com/Evangelioonnn/FPGA_musical_instrument/tree/codex/audio-integration-pack)。本页已更新；main 下其余文件仍是首次交接的历史基线，开发前请切换到该交接分支。** 当前交接提交为 `05b2d75`，音频/传输代码基线为 `e500e30`。

本页的交接链接明确指向最新分支，避免打开旧接口、旧状态或旧演示。首次进入请按下面的角色入口阅读。

| 目的 | 最新入口 |
|---|---|
| 了解当前成果、验证边界和下一步 | [STATUS](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/project/STATUS.md) |
| A：声音与总集成 | [ROLE_A](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/team/ROLE_A.md) |
| B：操控布局、控制板、器件与IO | [ROLE_B](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/team/ROLE_B.md) |
| C：屏幕交互、可视化、蓝牙与曲目引导 | [C交接与设计目标](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/team/C_HANDOFF_AND_DISPLAY_PLAN.md) → [ROLE_C](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/team/ROLE_C.md) |
| 导入音频、状态/PCM跨域与配置回复 | [音频接入包](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/project/audio_integration/README.md) |
| 三人资源与IO分配 | [最新预算](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/team/RESOURCE_BUDGET_V1.md) |
| 官方要求与板卡事实 | [REQUIREMENTS](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/project/REQUIREMENTS.md) · [BOARD](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/board/BOARD.md) · [DISPLAY](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/board/DISPLAY.md) |

## 已完成到哪里

当前演奏基线是 [audio_core_v2](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/project/audio_core_v2/README.md)，用户已认可完整版本的总体听感。五音色固定ID为 **0钢琴、2 Warm pluck、3 Metallic bell、4 Drive lead、5可编辑四谐波**；ID1旧拨弦保留历史源码，退出后续菜单。

- 0/3/4/5共享32声部槽，Warm pluck物理池12，混合及尾音总数≤32。满载拒收新音、不偷音、不按活跃数归一化；谐波每音固定V1的1/4，拨弦原电平。
- 已有主音量、双区八度、普通/选择性延音、释放、ADSR覆盖、Lead滑入/弯音/颤音、可旁路短房间效果，以及四谐波持续音平滑编辑。Warm pluck保持自然衰减。
- 4×4矩阵、EC11和板载按键已用于实际演奏验证；逻辑接口支持25键/两区。五推子计划由同颗8通道12bit SPI ADC采集，CH0主音量、CH1～4谐波；实体ADC与最终控制板尚未接入。
- 普通HDMI显示器已实测独立彩条1920×1080、约61Hz。成品UI、FFT、蓝牙、脱机曲目与实体LED尚待C/B实现，音频与显示整机尚未合并。
- 接入包已有真实状态、DAC前PCM、配置ACK跨域桥、精简解包、mock和源码清单。完整核心联动验证的具体边界见其VALIDATION，不将旧通过记录算作本轮新测试。

**音频听感认可不等于整机全部验收。** 模拟杂音根因、模拟端延迟/SNR、V2满载实物工况及音频/显示/蓝牙整机仍需验证。数字矩阵至串行字最坏2.12198ms不是模拟端延迟。

V2可下载顶层为 `audio_v2.gprj / audio_v2_top / 19 IO`，50MHz PnR为24052 Logic、10684 Register、66 BSRAM、24.5 DSP，setup余量0.632ns。保留接口审计余量仅0.076ns，且不含C、不可下载；合并后必须重新PnR。C预留13k Logic、10k Register、26 BSRAM、16 DSP、1 PLL，详细范围以预算为准。

## 队员与Codex如何开工

先切换到最新交接分支，按其 **AGENTS → STATUS → REQUIREMENTS → PROJECT_INDEX → 角色入口 → 目录内AGENTS** 阅读，再从交接基线创建自己的 `codex/` 任务分支。GitHub共享代码和结论，不共享聊天记忆。

```powershell
git fetch origin
# 本地干净时使用；已有改动先保存，避免覆盖队友工作
git switch --track origin/codex/audio-integration-pack
# 按角色建立自己的任务分支，例如C的首屏
git switch -c codex/c-display-console
python tools/check_repository.py
```

若交接分支已在本地存在，使用 `git switch codex/audio-integration-pack`，再按[协作工作流](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/team/WORKFLOW.md)同步。C可用mock独立做屏幕/协议，B可独立设计控制板，无需等其它模块完成。

提交源码、约束、IP配置、测试、生成脚本和必要ROM数据；不提交impl、比特流、ModelSim库、安装包、许可证或凭据。Pull或外部修改gprj后重开Designer，核对顶层和IO数；接入包审计/示例不是可烧录顶层。

## 最新工程分区

以下目录以交接分支为准；[工程索引](https://github.com/Evangelioonnn/FPGA_musical_instrument/blob/codex/audio-integration-pack/docs/catalog/PROJECT_INDEX.md)区分当前、回退、实验与失败候选。

| 目录 | 内容 |
|---|---|
| `project/audio_core_v2`、`project/audio_integration` | 当前音频基线与接入包 |
| `hardware/interaction` | B的操控布局、原理图/PCB、线束与机械配合 |
| `project/visual`、`project/communication`、`host`、`assets` | C的显示、通信、客户端和离线素材 |
| `docs/project`、`docs/team`、`docs/interfaces` | 当前状态、预算、分工与共享契约 |
| `docs/board`、`references`、`evidence` | 板卡事实、官方规则/资料及验证证据 |
| `docs/history`、旧实验工程 | 历史、诊断和回退；旧默认音色/待测结论不覆盖新决定 |

音频与显示核心使用FPGA硬件逻辑，不用软核CPU替代，不播放整段预录PCM冒充实时合成。电脑/MATLAB可离线准备素材或作客户端。采购/投板、改写Flash、正式比赛发布及队友消息按用户明确授权执行。
