# FPGA 实时电子乐器 · 三人协作仓库

2026 嵌入式芯片与系统设计竞赛，高云 FPGA 创新设计赛道，选题二「基于 FPGA 的实时多音色合成电子乐器引擎」。板卡：**Sipeed Tang Mega 60K 基础套餐＋Tang Mega NEO Dock**。目标：2026年11月前形成可以实际演奏、可测量、可复现的作品。

**当前是开发与交接基线，不是完成版乐器。** `final_dual_timbre` 的 harmonic_piano/pluck、矩阵、旋钮和板载键已获用户板测认可，是音频方向第一版完整演示；独立彩条已在普通HDMI显示器稳定显示1920×1080、61Hz。两者尚未合并，压力/蓝牙/实时可视化与成品控制板仍待实现；模拟噪声根因未查明。最新事实以[项目状态](docs/project/STATUS.md)为准。

**9月26日团队开工入口：** [A/B/C资源与接口预算V1](docs/team/RESOURCE_BUDGET_V1.md)。B按12根外接信号上限规划，C按4根蓝牙信号及专用TMDS链路、26块BSRAM/16 DSP规划；音频单独预留68块BSRAM，须由A优化后达成。本分支为`codex/resource-feature-budget`，下列9月19–22日记录保留历史边界，不能覆盖本轮板测与音色选择。

**9月20日旋钮候选：** [knob_suite](project/input/knob_suite/README.md)提供逐格完整弹奏、音量、三音色、释放、回声五份固件；11项数字仿真、独立音频数值核对及五份50MHz构建通过。首次板测认可音量/释放控制及基础弹奏，但快转起音和转动切换音色时有新增杂音，详见[板测记录](evidence/knob_suite_2026-09-20/BOARD_LISTENING.md)。操作见[旋钮验收指南](docs/project/KNOB_REVIEW_2026-09-20.md)。分支`codex/knob-performance-suite`，共享接口边界见[候选接口](docs/interfaces/KNOB_CANDIDATE.md)。

**9月19日夜间任务分支：** 新增[system集成候选](project/system/README.md)、输入RTL、真实观测接口、长音诊断和效果实验；已数字验证，未新增真实上板验收。先读[早上验收指南](docs/project/MORNING_REVIEW.md)，B/C看[system接口](docs/interfaces/SYSTEM_V0.md)。这批工作在`feat/playable-system-v0`，不要求大家直接在A的任务分支共同开发。

**新音色任务分支：** `feat/fm-pluck-rtl`在system v0分支上新增[FM/拨弦单声部RTL](project/experiments/timbre/README.md)及真实RTL试听、数值测试和独立构建。用户已上板试听：主体与WAV相符，pluck杂音很轻、FM杂音明显；音质仍待定位，未接入整机音色切换。

**9月21/22日当前任务：** [matrix_playable](project/input/matrix_playable/README.md)把矩阵、旋钮、三个板载用户键和八声部三音色合成到一份固件；数字验证和50MHz PnR已通过，长参考音频/交接证据正在整理，真实外设与音质仍待板测。拨弦保持自然衰减，回声/选择性延音暂缓。[接线](project/input/matrix_playable/WIRING.md) · [实例接口](docs/interfaces/MATRIX_PLAYABLE_V1.md) · [IP与资源路线](docs/project/IP_RESOURCE_PLAN.md)。

## 从这里接手

| 角色 | 负责什么 | 开工入口 |
|---|---|---|
| A：核心与总集成 | FPGA合成/效果、音质、统一顶层/约束、资源时序和整机 | [A交接](docs/team/ROLE_A.md) |
| B：实体操控 | 交互方式、手感布局、控制板原理图/PCB、器件/IO需求和线束 | [B交接](docs/team/ROLE_B.md) → [控制硬件目录](hardware/interaction/README.md) |
| C：蓝牙与显示 | 蓝牙扩展、外接显示器、FPGA实时可视化；具体效果由C设计 | [C交接](docs/team/ROLE_C.md) → [通信](project/communication/README.md) / [显示](project/visual/README.md) |

每位队员和Codex按顺序读：[AGENTS.md](AGENTS.md) → [当前状态](docs/project/STATUS.md) → [官方指标与项目边界](docs/project/REQUIREMENTS.md) → [板卡事实](docs/board/BOARD.md) → 对应角色入口 → [接口](docs/interfaces/README.md)。然后从角色文档的首轮任务开始，不必先读完全部历史或所有RTL。

工程是否可以复用、只是候选、仅用于诊断或已经归档，统一看[工程分类索引](docs/catalog/PROJECT_INDEX.md)；验证输出看[证据索引](evidence/INDEX.md)。不要只根据文件夹名称或某次仿真通过来判断整机状态。

## 仓库分区

| 目录 | 内容 |
|---|---|
| `docs/project/` | 当前进度、赛题指标、架构、路线 |
| `docs/catalog/` | 工程分类、证据分类和文件生命周期 |
| `docs/board/` | 实物事实、IO与电气约束、显示资料差异 |
| `docs/team/`、`docs/interfaces/` | 分工、GitHub流程、首轮任务、共享接口 |
| `docs/history/` | 原工作区有价值的带日期规划/讨论，不作为当前默认决定 |
| `project/` | 可复现的音频参考源码/测试，以及未来通信/显示/输入模块 |
| `hardware/interaction/` | B的控制板、接口表、BOM、机械/测试记录 |
| `host/`、`assets/` | C的客户端工具与离线显示素材，当前仅交接说明 |
| `references/` | 官方赛题、精选板卡原始资料、来源与版本索引 |
| `evidence/` | 已完成验证摘要、少量日志、参考音频；不是板卡质量保证 |
| `tools/` | 仓库完整性检查；`templates/`为交接和板测模板 |

## 为什么现在就保留代码

已有HDL能说明真实的事件、参数、时序、波表和测试边界，比只给抽象接口更容易联调。此仓库保留其依赖和验证脚本；**先复用已验证部分，不要求B/C修音频算法，也不把实验工程直接视作最终集成工程。**

| 工程 | 用途与状态 |
|---|---|
| [final_dual_timbre](project/final_dual_timbre/README.md) | 当前已板测的音频完整演示：harmonic_piano/pluck、矩阵/旋钮/板载键；未整合显示/蓝牙 |
| [dvi_colorbar_probe](project/visual/dvi_colorbar_probe/README.md) | 普通HDMI显示器彩条已板测，是C的物理输出起点 |
| [system](project/system/README.md)、[input](project/input/README.md) | 原声不变的集成候选；输入/配置/观测数字验证，物理输入待绑定 |
| [lab](project/lab/README.md) | C4/A4长音与静音诊断，复用原音色及输出 |
| [experiments](project/experiments/README.md) | 16/32容量、短反馈延迟、FM/拨弦单声部新音色，成熟度分别标注 |
| [expression_baseline](project/expression_baseline/README.md) | 当前默认试听；8声部统一原音色、音量/力度/两类延音，自动演示；电脑可接受，板卡杂音待定位 |
| [instrument](project/instrument/README.md) | 原单声部正弦DDS＋ADSR，默认音色来源 |
| [expression](project/expression/README.md) | 表情、参数、状态接口候选；其他音色不作为默认，未接外设 |
| [polyphony](project/polyphony/README.md) | 较简单的四声部管理/混音参考 |
| [audio_probe](project/audio_probe/README.md)、`test` | 已上板的基本发声、PMOD点灯基线 |
| [audio_quality](project/audio_quality/NOISE_DIAGNOSIS.md)、[audio_format](project/audio_format/README.md) | 历史精度/串行格式A/B排查；没有解决尖锐声，保留避免重复试错 |

## 克隆和日常同步

推荐GitHub Desktop：克隆本仓库 → main上Fetch/Pull → 新建 `feat/你的任务` → 修改负责目录并测试 → Commit → Push → PR到main → 评审合并。A维护共享顶层/约束和接口集成；A的修改也让队友复核。**各自账号、各自本地副本，不通过ZIP覆盖对方目录。** 详见[协作操作](docs/team/WORKFLOW.md)。

Git只同步提交文件，不同步三人的对话。任务结论、接口变动与测试结果必须写回文档。项目在main上有记录的缺陷可以保留，不能隐瞒为“已验收”。

## 本机复现

工具基线：Gowin V1.9.12.03、GW5AT-LV60PG484AC1/I0、Device Version B；ModelSim ALTERA 10.1d曾成功运行纯RTL测试（不代表支持Gowin原语仿真）。Python 3用于分析/向量生成；部分历史分析脚本另需NumPy。无需MATLAB也能验证现有音频工程。

```powershell
# 在仓库根目录；把工具路径换成自己电脑上的位置。
& ./project/expression_baseline/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' -PythonExe python
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/expression_baseline/build.tcl
python tools/check_repository.py
```

运行后在本机产生的 `impl/pnr/expression_baseline.fs` 用于SRAM下载；不把18MB比特流和整个构建缓存作为日常Git内容。新克隆需要构建，参考音频和已有报告在[evidence](evidence/README.md)。Designer重新打开gprj后确认顶层 `expression_baseline_top`；不能使用旧窗口缓存的文件列表。

各工程的`sim/run.ps1`是仿真入口，`build.tcl`是对应Gowin构建入口。`project/expression/tools/record_validation.py`是旧一次性归档工具，依赖未随仓库提交的优化前报告和旧manifest，**不作为干净克隆验收入口**；重用前需按新报告改写归档流程。

## 架构与执行边界

- 音频生成、合成与实时显示核心用FPGA硬件逻辑，不以软核CPU或外部软件替代；不播放整段预录PCM冒充实时合成。
- MATLAB/Python可以离线生成图片/字模/ROM数据；「琴键照片转RGB→ROM→FPGA显示」只是C的候选，未冻结。
- 最终演奏面未定，琴键/网格等平等考虑；4×4只验证。B提出控制IO方案，A与C一起核对冲突后由A维护最终CST。
- FPGA绘图不能阻塞音频；蓝牙第一版调参/回传状态，实际模块、协议、显示分辨率由各负责人评估。
- 针位、电压、PCB投板和板卡操作以可核对的资料/实测为准。特别注意[显示资料冲突](docs/board/DISPLAY.md)和[DK_START与本板的区别](references/README.md)。

本仓库公开可读；写入协作需仓库所有者邀请队友。第三方资料保留原作者权利和来源，没有为整仓擅自添加统一开源许可证；新增引用素材须记录来源。安装包、个人许可证、凭据和本地缓存不提交。
