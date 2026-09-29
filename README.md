# FPGA 实时电子乐器 · 团队仓库

2026 嵌赛高云 FPGA 赛道选题二。板卡：**Tang Mega 60K 基础套餐＋Tang Mega NEO Dock**；三人团队，目标在11月前完成可演奏、可测量、可复现的作品。

## 当前入口 · 2026-09-29

**A/B/C从本页开始，不从历史工程文件名猜版本。**

**当前交接在 `codex/audio-integration-pack`，音频/接口基线 `e500e30`，其后为本轮文档更新。** 本轮Fetch核实 `main`仍是`4ada74e`初始交接，尚未合入这些成果；新成员先取本分支，从它创建各自工作分支，见[工作流](docs/team/WORKFLOW.md)。

| 目的 | 当前入口 |
|---|---|
| 了解当前成果、限制和下一步 | [STATUS](docs/project/STATUS.md) |
| B设计控制板，确认按键/推子/IO边界 | [ROLE_B](docs/team/ROLE_B.md) → [最新资源预算](docs/team/RESOURCE_BUDGET_V1.md) |
| C开始显示/蓝牙，无须等待控制板 | [C简要交接与屏幕设计目标](docs/team/C_HANDOFF_AND_DISPLAY_PLAN.md) → [ROLE_C](docs/team/ROLE_C.md) → [音频接入包](project/audio_integration/README.md) |
| 导入真实音频、跨域状态/PCM、提交配置 | [接入包](project/audio_integration/README.md) · [导入规则](docs/interfaces/AUDIO_IMPORT_V1.md) · [传输契约](docs/interfaces/AUDIO_TRANSPORT_V1.md) |
| 复现当前已认可的实物音频演奏 | [audio_core_v2](project/audio_core_v2/README.md)，顶层 `audio_v2_top`、19 IO |
| 核对比赛、硬件与显示事实 | [官方指标](docs/project/REQUIREMENTS.md) · [板卡](docs/board/BOARD.md) · [显示](docs/board/DISPLAY.md) |
| A继续总集成 | [ROLE_A](docs/team/ROLE_A.md) |

音频V2保留五音色固定ID **0/2/3/4/5**，四种谐波音色共享32声部、Warm pluck物理池12，混合及尾音总数≤32；不偷音、不按活跃数压音量。谐波每音固定为V1的1/4，拨弦原电平。用户已表示完整版本“听起来没什么毛病”，见[反馈范围](evidence/audio_core_v2_2026-09-29/BOARD_LISTENING.md)。

现有实物输入是4×4矩阵、EC11和板载键；逻辑接口支持25键/两区。五推子由同一颗8通道12bit SPI ADC采集，CH0主音量、CH1..4谐波系数；实体ADC和最终控制板尚未接入。独立TMDS彩条已在普通HDMI显示器稳定显示1920×1080、61Hz；实时显示、蓝牙和音频整机仍待C实现及联合验收。

接入包提供内部FPGA接口、源码清单和测试，不包含成品显示UI、FFT、无线帧协议或新的针位承诺。最新资源/50MHz时序按[原位更新的预算](docs/team/RESOURCE_BUDGET_V1.md)和接入包VALIDATION核对；独立模块报告不能相加当整机通过。模拟噪声根因、模拟端延迟/SNR仍未测定。

## 协作与复现

三人的Codex先读 `AGENTS.md` → STATUS → REQUIREMENTS → [工程分类](docs/catalog/PROJECT_INDEX.md) → 对应角色入口 → 负责目录内AGENTS。GitHub共享源码和结论，不共享聊天记忆。

通常每项任务从最新main建立 `codex/` 分支；当前main尚未合入本交接时，先从上述交接分支建立自己的分支，在负责目录开发，提交测试/证据，通过PR说明共享接口、电气、顶层或约束影响；A负责总集成。C可用接入包mock状态/PCM独立做显示，B可用现有模块验证手感，各自不必随音频实验换针位。细节见[三台电脑一块板卡的工作流](docs/team/WORKFLOW.md)。

在仓库根目录运行：

```powershell
python tools/check_repository.py
python project/audio_integration/tools/package_check.py --static-only
python project/audio_integration/sim/run_transport.py
```

ModelSim、Gowin和Python安装位置可用各脚本参数指定。需要完整音频回归、干净导出和PnR时按接入包README运行；接入包的逻辑示例/资源审计顶层不是可烧录板级工程。更新gprj后重新打开Designer并核对Top，避免把内部快照当几千个物理IO。

## 仓库分区

| 目录 | 内容 |
|---|---|
| `project/audio_core_v2` | 当前获听感认可的32/12声部演奏基线 |
| `project/audio_integration` | A提供的源码导入、传输桥、精简解包/mock、资源优化与验证 |
| `hardware/interaction` | B的布局、器件、原理图/PCB、线束与机械配合 |
| `project/visual`、`project/communication` | C的显示、蓝牙；当前独立彩条与开发入口 |
| `assets`、`host` | 素材生成/来源、客户端和通信测试 |
| `docs/project`、`docs/team`、`docs/interfaces` | 当前事实、预算、分工与共享契约 |
| `docs/board`、`references` | 板卡电气、官方规则/资料与来源 |
| `evidence` | 数字、构建和板测证据；[索引](evidence/INDEX.md) |
| `docs/history`、各实验工程 | 带日期的历史与对照；不是默认开发入口 |

保留V1/final及诊断实验便于回退。[工程索引](docs/catalog/PROJECT_INDEX.md)区分复用、候选、诊断和失败边界。旧根入口和[接入包前README快照](docs/history/README_BEFORE_INTEGRATION_2026-09-29.txt)保留历史，不覆盖当前决定。

提交源码、约束、IP配置、重建脚本与必要ROM数据。**不提交** `impl`、比特流、ModelSim库、安装包、许可证或凭据。本机WAV是RTL参考证据，不回灌FPGA播放；正式规则见官方PDF，学长指导属于非官方建议。

普通阅读、可逆编辑、仿真和资料整理不另设批准流程；采购/投板、改写Flash、发布比赛正式版本、向队友发送消息不由普通开发任务自动授权。远端push依用户本次授权执行。
