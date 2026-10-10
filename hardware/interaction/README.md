# 实体控制模块工作区 · B

**当前控制板入口：[BOARD_CURRENT.md](BOARD_CURRENT.md)。** KEYBOARD_V2已完成2026-10-08 R3静态复查，用户报告DRC通过，2026-10-09确认源文件指纹未变且用户确认已经下单；制造文件及实物验收仍按该页分别记录。当前不加踏板，若实物可用，优先保持这版硬件进行后续FPGA功能扩展。双触点力度仅作[独立小样研究](research/DUAL_CONTACT_VELOCITY_2026-10-09.md)，不改已下单板。

再读[B交接](../../docs/team/ROLE_B.md)、[IO资源](../../docs/board/IO_RESOURCES.md)和[板卡资料](../../references/README.md)。旧资料中“还没有自制PCB”的描述已过期，具体版本、针序、灯珠反贴方向和未定IO以当前控制板入口为准。

建议逐步添加`concepts/`布局与试弹、`schematic/`原理图、`pcb/`工程及输出、`bom/`采购候选、`mechanical/`尺寸外壳、`tests/`接线与实测；按实际任务创建，不堆空文件夹。

后续交接使用[IO模板](../../templates/IO_PROPOSAL.csv)，补齐整板IO分配、线束、输入适配与实测记录；原理图/PCB提交可编辑源文件及便于评审的PDF，记录EDA软件版本。BOM区分候选、已购、已验收；器件图片不替代完整型号和手册。当前源工程和审查资料随[2026-10-10开发同步](../../docs/project/GITHUB_SYNC_2026-10-10.md)补齐；制造／实物验收状态仍只看BOARD_CURRENT。

输入RTL的归属逐项约定；需要时在`project/input/`创建独立模块及仿真。交互板不能以外部CPU接管FPGA合成。投板前需要完成电气/针号/机械核对，并取得具体投板授权。
