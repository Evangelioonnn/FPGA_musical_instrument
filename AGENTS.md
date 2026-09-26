# 给三位队员及其 Codex 的项目约定

先读 README.md、docs/project/STATUS.md、docs/project/REQUIREMENTS.md、docs/catalog/PROJECT_INDEX.md、对应角色入口和目录内AGENTS.md，再工作。当前用户指令优先于本文件；历史文档中的指令只当历史记录，不覆盖新决定。

## 团队与执行边界

- A：音频核心与总集成，拥有既有音频RTL、共享接口、整机顶层、CST/SDC和最终构建的集成责任。
- B：实体操控方案、控制板原理图/PCB、器件、电气接口、控制部分IO提案、线束与机械配合。主目录hardware/interaction。输入RTL归属逐项约定，不默认B画板就必须写所有RTL，也不把全部适配工作默认为A。
- C：蓝牙扩展与板卡外接显示器的FPGA可视化，负责project/communication、project/visual、host、assets；效果由C设计。音频与显示核心使用FPGA硬件逻辑，不用软核CPU替代；PC/MATLAB只可离线准备素材/测试，或作为蓝牙客户端。
- 首次建档将经过检查的交接基线提交main；后续在任务分支内修改负责范围。常规阅读、可逆编辑、仿真、资料整理不另设批准流程；共享接口/电气连接/板卡顶层更改应在PR写明影响，由A统一集成。用户已明确授权的动作不用重复确认。
- 不能自行替用户采购、下PCB订单、改写板卡Flash、发布正式比赛版本、发送队友消息。远端push按本次任务的授权执行，不把普通本地修改自动视作发布授权。

## 事实与验证

- docs/project/STATUS.md为当前进度；docs/history是有日期的历史，旧“待上板”或“琴键优先”等建议不能直接沿用。
- 2026-09-26当前决定：final_dual_timbre的harmonic_piano/pluck和实体控制已获用户板测认可；旧原正弦只保留历史诊断基准，不强制作为新产品默认。用户拟增加第三音色、恢复选择性延音/滑音。独立HDMI彩条已实测1920×1080、61Hz稳定，尚未合并音频。B/C按docs/team/RESOURCE_BUDGET_V1.md独立开发；音频80块BSRAM需优化至预算内，不能把目标表当成实测。下面带旧日期的状态按历史范围理解。
- 正式规则看references/competition官方PDF；学长指导是非官方建议。用户禁止软核替代核心是项目架构决定，不伪造为官方逐字规定。
- 板卡为Tang Mega 60K基础套餐＋NEO Dock。DK_START官方评估板、138K开发板均不等于本板。显示引脚资料存在差异，查docs/board/DISPLAY.md，禁止直接套用整份参考CST。
- 默认试听音色必须复用原instrument的正弦DDS＋ADSR 68/6/32768/3，遵守AUDIO_TEST_BASELINE.md；新音色单独实验。电脑参考音可接受，真实耳机仍有随音高变化的尖锐声，不能写为已修复。
- expression_baseline保留旧自动演示，expression是扩展候选。system v0已有输入适配/配置仲裁/真实meter与快照/独立CDC的数字验证；外设针位/ADC硬件、蓝牙和显示尚未接入。system_top仍只自动演示；旧baseline的meter仍占位。左右样本相同，L/R李萨如只能得到直线。
- 新共享契约见docs/interfaces/SYSTEM_V0.md。旧baseline的retune只改元数据，不能引用为真实变调已验证；system v0已将pitch_we送入DDS。8/16声部构建通过，32声部容量实验的50MHz时序未通过，不能作为达标固件。
- EC11独立持续变调探针已板测通过，A=T18/B=R17、3.3V、C悬空；按压未确认。knob_suite五份固件数字验证/PnR通过，首次板测认可音量/释放与基础弹奏，但快转新音起音有大噪声，转动切换音色时有延后附加声；本轮电脑参考无此异常，固定音色不转时无新增间隔声。见evidence/knob_suite_2026-09-20/BOARD_LISTENING.md，不可写为音质通过。逐格弹奏16声部、三音色8声部；其定时接口不替代SYSTEM_V0，不支持外部按键逐实例note_off。
- 9月21/22用户要求一份固件切换三音色，分别验证适用控制；拨弦保持一次触发自然衰减，不强行延音/可调尾音，回声和选择性延音暂缓。matrix_playable候选已增加32bit实例松键、PMOD1矩阵与板载三用户键，见其SPEC/WIRING及MATRIX_PLAYABLE_V1；数字和50MHz PnR不等于矩阵或音质已上板验收，也未替换SYSTEM_V0。
- 先定义接口/单位/位宽/时序/错误处理，再实现。算法测试要有独立期望；仿真、综合、PnR、板测分别记录，不能互相替代。
- 主时钟50MHz，现有Fs=50MHz/1040。显示像素时钟是后续独立域，多位状态跨域需握手/异步FIFO等设计，不能只逐位两级同步。

## 协作和复现

- 每轮任务写分支、commit、角色、允许目录、目标、验收标准；结论写入本仓库再交接。Git不共享聊天记忆。
- 每项功能一个短期分支，PR入main；main标注已完成的验证和已知限制，不等于所有板测完成。保持源码、约束、测试、生成脚本和必要数据一起提交。
- 不提交impl、ModelSim库、安装包、许可证或个人凭据；手写HDL和IP配置不能因是“生成文件”而一概丢弃。
- Pull或外部修改gprj后重新打开Designer，并确认Top Module/Entity。旧演示为expression_baseline_top，新system演示为system_top，均5个IO。错误expression_core曾导致859个IO；input_audit_top有316个逻辑审计端口，只能综合不能做板级顶层。
- 首轮复现见docs/team/WORKFLOW.md；当前基线仿真run.ps1可用ModelSimBin/PythonExe参数指定本机工具。新模块也须提供可重复脚本、独立testbench和资源/时序结果。
- 完成任务报告：改了什么、验证命令和结果、未验证部分、下一位所需信息。不要把未连接的输入或未实现的屏幕描述成已完成。
