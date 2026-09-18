# 实体控制模块工作区 · B

先读[B交接](../../docs/team/ROLE_B.md)、[IO资源](../../docs/board/IO_RESOURCES.md)和[板卡资料](../../references/README.md)。目前是交接入口，还没有自制PCB设计。

建议逐步添加`concepts/`布局与试弹、`schematic/`原理图、`pcb/`工程及输出、`bom/`采购候选、`mechanical/`尺寸外壳、`tests/`接线与实测；按实际任务创建，不堆空文件夹。

第一份PR：至少两份交互草案、IO提案、关键器件和未决项。使用[IO模板](../../templates/IO_PROPOSAL.csv)；原理图/PCB提交可编辑源文件及便于评审的PDF，记录EDA软件版本。BOM区分候选、已购、已验收；器件图片不替代完整型号和手册。

输入RTL的归属逐项约定；需要时在`project/input/`创建独立模块及仿真。交互板不能以外部CPU接管FPGA合成。投板前需要完成电气/针号/机械核对，并取得具体投板授权。
