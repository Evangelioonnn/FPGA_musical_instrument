# 原始资料与来源

这里保存从用户下载目录精选的原始文件，未修改原文件内容。来源、原文件名、字节数与SHA256见[manifest](manifest.json)；其中官网入口不代表精确下载URL。本仓库不改变原作者权利，也未为这些第三方文件重新授权。

官方赛题优先；学长写的《实时电子音乐系统.pdf》只是非官方建议，本次不公开搬运其全文。宣讲材料、安装包、许可文件和大量不相关芯片/CPU手册未整体上传。主要官方入口：[Sipeed Wiki](https://wiki.sipeed.com/hardware/zh/tang/tang-mega-60k/mega-60k.html)、[60K官方例程](https://github.com/sipeed/tangMega-60K-example)、[Gowin IP目录](https://www.gowinsemi.com.cn/ip/index)。

## 不能混用的板型/版本

用户后来下载的`DBUG1288-1.0.1_DK_START_GW5AT-LV60PG484A_V1.2开发板用户手册.pdf`及同名DK_START原理图，是Gowin自己的DK_START开发板，**不是Sipeed Tang Mega NEO Dock**。可参考芯片/IP，不可作为本板接线表；本次只记录区别，不纳入本板电气基准。GW5AST-138 Pinout手册也不是GW5AT-60B的直接封装依据。

NEO Dock原理图为2025-03-31 Rev1.4，iBOM为2024-09-23；核心板30353/30354与实物版本尚未一一核实。全引脚CST与显示图纸存在差异，详见[DISPLAY](../docs/board/DISPLAY.md)。全CST带有多外设约束、不同Bank电压和位置设置，不能直接加入本项目。

## 已纳入的资料

| 文件 | 用途/限制 | 大小 |
|---|---|---|
| [competition/gowin_2026_topics.pdf](competition/gowin_2026_topics.pdf) | 官方赛题：选题二PDF第15–16页 | 1.38 MiB |
| [board/neo_dock_60k_schematic.pdf](board/neo_dock_60k_schematic.pdf) | NEO Dock 60K；Rev1.4，2025-03-31 | 5.30 MiB |
| [board/core_30353_schematic.pdf](board/core_30353_schematic.pdf) | 核心板30353；不要假定等于实物版本 | 0.69 MiB |
| [board/core_30354_schematic.pdf](board/core_30354_schematic.pdf) | 核心板30354；需和实物核对 | 0.78 MiB |
| [board/full_pins_reference.cst](board/full_pins_reference.cst) | 只作参考；显示标注与NEO图纸有差异 | 0.02 MiB |
| [board/neo_dock_ibom.html](board/neo_dock_ibom.html) | 交互BOM，日期2024-09-23；定位元件，不保证网络版本一致 | 0.69 MiB |
| [board/assembly.pdf](board/assembly.pdf) | 共享装配参考，核对适用版本 | 1.31 MiB |
| [mechanical/core_dimensions.pdf](mechanical/core_dimensions.pdf) | 核心板尺寸参考 | 0.17 MiB |
| [mechanical/neo_dock_dimensions.pdf](mechanical/neo_dock_dimensions.pdf) | NEO Dock尺寸参考 | 0.20 MiB |
| [mechanical/core_30354_refdes.pdf](mechanical/core_30354_refdes.pdf) | 元件参考标识图 | 0.20 MiB |
| [mechanical/core_dimensions.dxf](mechanical/core_dimensions.dxf) | 核心板可编辑尺寸 | 5.37 MiB |
| [mechanical/neo_dock_dimensions.dxf](mechanical/neo_dock_dimensions.dxf) | NEO Dock可编辑尺寸 | 5.38 MiB |
| [mechanical/neo_dock_3d.7z](mechanical/neo_dock_3d.7z) | 原始压缩包；用于空间参考，安装前实测核对 | 10.87 MiB |
| [mechanical/core_3d.7z](mechanical/core_3d.7z) | 原始核心板3D压缩包 | 3.98 MiB |
| [devices/PT8211_V1.6.pdf](devices/PT8211_V1.6.pdf) | PTC DAC手册；LSBJ与电气特性 | 0.41 MiB |
| [devices/UG299_ADC.pdf](devices/UG299_ADC.pdf) | 系列ADC指南，不直接证明60K外部ADC通道 | 0.95 MiB |
| [eda/SUG100_IDE.pdf](eda/SUG100_IDE.pdf) | 用户从官网下载的EDA参考；依本机软件版本判断适用性 | 2.93 MiB |
| [eda/SUG1018_AroraV_constraints.pdf](eda/SUG1018_AroraV_constraints.pdf) | 用户从官网下载的EDA参考；依本机软件版本判断适用性 | 3.88 MiB |
| [eda/SUG940_timing.pdf](eda/SUG940_timing.pdf) | 用户从官网下载的EDA参考；依本机软件版本判断适用性 | 1.88 MiB |
| [eda/SUG283_primitives.pdf](eda/SUG283_primitives.pdf) | 用户从官网下载的EDA参考；依本机软件版本判断适用性 | 1.35 MiB |
| [eda/SUG949_HDL_style.pdf](eda/SUG949_HDL_style.pdf) | 用户从官网下载的EDA参考；依本机软件版本判断适用性 | 1.31 MiB |
| [eda/SUG1220_Tcl.pdf](eda/SUG1220_Tcl.pdf) | 用户从官网下载的EDA参考；依本机软件版本判断适用性 | 1.16 MiB |

3D压缩包和DXF是为B的面板/外壳工作保留的原始参考，不重复存放多个压缩格式。EDA手册挑选常用的IDE、约束、原语、HDL风格和Tcl；更多手册按需从Gowin官网查找，版本不能只凭“较新”替换实际器件依据。

## 开源音色算法参考

历史研究见[TIMBRE_PLAN](../docs/history/TIMBRE_PLAN.md)：STK拨弦、Plaits弦引擎、OPL3 FPGA等。当前没有移植这些实现；其许可判断是当时调研记录，真正引入代码时需固定commit、逐文件核对许可/依赖、保留归属并验证Gowin兼容性。它们的别的平台资源数据不是本板预测。
