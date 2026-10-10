# FPGA 实时电子乐器 · 团队仓库

2026 嵌赛高云 FPGA 赛道选题二。板卡：**Tang Mega 60K 基础套餐＋Tang Mega NEO Dock**；三人团队，目标在11月前完成可演奏、可测量、可复现的作品。

## 当前开发入口 · 2026-10-10

本次同步补齐此前未上传的 Looper／全局节拍器、新鼓组与 C 接口，以及当前控制板源文件和审查资料。[同步范围与检查](docs/project/GITHUB_SYNC_2026-10-10.md)区分当前候选、历史对照和实测范围。

| 目的 | 入口 |
|---|---|
| 了解进度、比赛指标和资源 | [STATUS](docs/project/STATUS.md) · [REQUIREMENTS](docs/project/REQUIREMENTS.md) · [资源预算](docs/team/RESOURCE_BUDGET_V1.md) |
| 试听最新鼓组，演奏与全局节拍器 | [looper_session_v2](project/looper_session_v2/README.md) → [BOARD_TEST](project/looper_session_v2/BOARD_TEST.md)；Top **looper_session_top**，19 IO |
| C 接真实 Looper 状态、控制与波形 | [C_HANDOFF](project/looper_session_v2/C_HANDOFF.md) → [LU1／命令契约](project/looper_session_v2/UI_CONTRACT.md)；不是旧LR1解包器 |
| A/B 接当前自制控制板 | [BOARD_CURRENT](hardware/interaction/BOARD_CURRENT.md) → [R3审查](hardware/interaction/reviews/2026-10-08/RECHECK_R3.md)；可编辑源 `BOARD/KEYBOARD_V2.eprj` |
| 复现已认可的旋律演奏回退 | [audio_core_v2](project/audio_core_v2/README.md)；Top **audio_v2_top**，19 IO |
| 非Looper音频／状态接入 | [audio_integration](project/audio_integration/README.md) · [导入规则](docs/interfaces/AUDIO_IMPORT_V1.md) · [传输契约](docs/interfaces/AUDIO_TRANSPORT_V1.md) |
| C 的显示／蓝牙与视觉效果目标 | [ROLE_C](docs/team/ROLE_C.md) · [显示规划](docs/team/C_HANDOFF_AND_DISPLAY_PLAN.md) |
| 分工、工程分类及板卡事实 | [ROLE_A](docs/team/ROLE_A.md) · [ROLE_B](docs/team/ROLE_B.md) · [PROJECT_INDEX](docs/catalog/PROJECT_INDEX.md) · [板卡](docs/board/BOARD.md) · [显示](docs/board/DISPLAY.md) |

五旋律音色固定ID **0/2/3/4/5**：钢琴、Warm pluck、Metallic bell、Drive lead、自定义四谐波。共享32旋律槽，含12个Warm pluck物理槽；Looper候选另有8鼓槽、4轨×4层、2048事件和40～240 BPM全局节拍器。满池策略和固定电平见各工程契约，不用活跃数归一化，不把四谐波冒充四个独立声部。

最新鼓组／C接口候选完成48项数字回归和独立19针50MHz PnR，**75 BSRAM /32.5 DSP、setup/hold 0/0、余量1.117ns**。保留全部接口的50/150MHz审计仍有时序违例，尚无整机资格。原五音色与基本循环已有用户反馈；新鼓组、复杂Looper操作、模拟杂音／SNR／延迟仍待相应验收。

当前下载候选仍接旧4×4矩阵、一个EC11和三板载键。自制控制板为25演奏键＋11功能键、6×6二极管矩阵、三带按压编码器、五推子／双轴摇杆＋MCP3208、25 RGB及四状态灯，**不能直接套旧4×4 CST**。制造、到货、焊接和板测分别以BOARD_CURRENT记载为准；本次同步不改变这些验收状态。

独立1080p TMDS彩条已实测1920×1080、61Hz稳定；用户报告C的屏幕已有按键映射。本次提供真实Looper接口，C的显示／蓝牙源码和新控制板仍待后续联合接入与PnR，未替C合并其独立分支。

## 历史对照与协作

`audio_core_v2`保留已认可演奏回退；`looper_refinement_lab`保留首轮基本循环反馈；`looper_convergence_lab`是未晋升的优化对照；`looper_lab`是原始事件循环版本。旧[总验收指南](docs/project/LOOPER_TOTAL_ACCEPTANCE_2026-10-09.md)已标注日期，最新入口以本页为准。9月29日音频／传输代码起点`e500e30`仍是历史基线，不覆盖10月新增候选。

各人的Codex先读 `AGENTS.md` → STATUS → REQUIREMENTS → PROJECT_INDEX → 对应角色入口 → 目录内AGENTS。Git共享源码和结论，不共享聊天记忆。每项任务从最新main创建 `codex/` 分支，经PR说明共享接口、电气、顶层与约束影响；按[WORKFLOW](docs/team/WORKFLOW.md)协作。已有工作先提交，再Fetch并合并origin/main，避免覆盖队友成果。

```powershell
git fetch origin
git switch -c codex/your-task origin/main
python tools/check_repository.py
python tools/check_sync_snapshot.py
```

Designer更新gprj后重新打开并确认Top。`session_link`及audit是逻辑／资源审计模块，不能直接下载。构建、仿真和参考音按各lab的README重建；ModelSim／Gowin路径可指定本机工具。历史证据记录原始字节SHA，Git换行可能不同；[本次源码清单](evidence/github_sync_2026-10-10/SOURCE_MANIFEST.json)额外提供LF规范化校验，源码一致不等于已重新板测。

## 仓库分区

`project/`放音频、输入、Looper及C的显示／通信；`hardware/interaction/`和`BOARD/KEYBOARD_V2.eprj`放当前控制板；`docs/`放进度、预算、契约与历史；`evidence/`放分层验证记录；`references/`放精选官方资料，`assets/host`放离线素材和客户端。

提交源码、约束、IP配置、复现脚本和必要证据摘要。**固件、impl、仿真库、临时日志、EDA自动备份、安装包及凭据留在本机**；FS/WAV通过脚本生成，参考WAV不回灌FPGA冒充实时合成。合入开发main不是发布正式比赛成品；官方规则与学长建议分别记录，音频／显示核心不用软核替代。
