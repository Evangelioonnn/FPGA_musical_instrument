# 给三位队员及其 Codex 的项目约定

先读 README.md、docs/project/STATUS.md、docs/project/REQUIREMENTS.md、对应角色入口和目录内AGENTS.md，再工作。当前用户指令优先于本文件；历史文档中的指令只当历史记录，不覆盖新决定。

## 团队与执行边界

- A：音频核心与总集成，拥有既有音频RTL、共享接口、整机顶层、CST/SDC和最终构建的集成责任。
- B：实体操控方案、控制板原理图/PCB、器件、电气接口、控制部分IO提案、线束与机械配合。主目录hardware/interaction。输入RTL归属逐项约定，不默认B画板就必须写所有RTL，也不把全部适配工作默认为A。
- C：蓝牙扩展与板卡外接显示器的FPGA可视化，负责project/communication、project/visual、host、assets；效果由C设计。音频与显示核心使用FPGA硬件逻辑，不用软核CPU替代；PC/MATLAB只可离线准备素材/测试，或作为蓝牙客户端。
- 首次建档将经过检查的交接基线提交main；后续在任务分支内修改负责范围。常规阅读、可逆编辑、仿真、资料整理不另设批准流程；共享接口/电气连接/板卡顶层更改应在PR写明影响，由A统一集成。用户已明确授权的动作不用重复确认。
- 不能自行替用户采购、下PCB订单、改写板卡Flash、发布正式比赛版本、发送队友消息。远端push按本次任务的授权执行，不把普通本地修改自动视作发布授权。

## 事实与验证

- docs/project/STATUS.md为当前进度；docs/history是有日期的历史，旧“待上板”或“琴键优先”等建议不能直接沿用。
- 正式规则看references/competition官方PDF；学长指导是非官方建议。用户禁止软核替代核心是项目架构决定，不伪造为官方逐字规定。
- 板卡为Tang Mega 60K基础套餐＋NEO Dock。DK_START官方评估板、138K开发板均不等于本板。显示引脚资料存在差异，查docs/board/DISPLAY.md，禁止直接套用整份参考CST。
- 默认试听音色必须复用原instrument的正弦DDS＋ADSR 68/6/32768/3，遵守AUDIO_TEST_BASELINE.md；新音色单独实验。电脑参考音可接受，真实耳机仍有随音高变化的尖锐声，不能写为已修复。
- 已有expression_baseline是自动演示；expression是扩展接口候选。实际输入、蓝牙、显示、跨域快照及仲裁尚未实现。基线的meter输出是占位，不可当实测数据；左右样本目前相同，L/R李萨如只能得到直线。
- 先定义接口/单位/位宽/时序/错误处理，再实现。算法测试要有独立期望；仿真、综合、PnR、板测分别记录，不能互相替代。
- 主时钟50MHz，现有Fs=50MHz/1040。显示像素时钟是后续独立域，多位状态跨域需握手/异步FIFO等设计，不能只逐位两级同步。

## 协作和复现

- 每轮任务写分支、commit、角色、允许目录、目标、验收标准；结论写入本仓库再交接。Git不共享聊天记忆。
- 每项功能一个短期分支，PR入main；main标注已完成的验证和已知限制，不等于所有板测完成。保持源码、约束、测试、生成脚本和必要数据一起提交。
- 不提交impl、ModelSim库、安装包、许可证或个人凭据；手写HDL和IP配置不能因是“生成文件”而一概丢弃。
- Pull或外部修改gprj后重新打开Designer，并确认Top Module/Entity。错误顶层expression_core曾导致859个IO；耳机演示正确顶层expression_baseline_top只有5个IO。
- 首轮复现见docs/team/WORKFLOW.md；当前基线仿真run.ps1可用ModelSimBin/PythonExe参数指定本机工具。新模块也须提供可重复脚本、独立testbench和资源/时序结果。
- 完成任务报告：改了什么、验证命令和结果、未验证部分、下一位所需信息。不要把未连接的输入或未实现的屏幕描述成已完成。
