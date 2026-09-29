# 给三位队员及其 Codex 的项目约定

先读 README.md、docs/project/STATUS.md、docs/project/REQUIREMENTS.md、docs/catalog/PROJECT_INDEX.md、对应角色入口和目录内AGENTS.md，再工作。当前用户指令优先于本文件；历史文档中的指令只当历史记录，不覆盖新决定。

## 团队与执行边界

- A：音频核心与总集成，拥有既有音频RTL、共享接口、整机顶层、CST/SDC和最终构建的集成责任。
- B：实体操控方案、控制板原理图/PCB、器件、电气接口、控制部分IO提案、线束与机械配合。主目录hardware/interaction。输入RTL归属逐项约定，不默认B画板就必须写所有RTL，也不把全部适配工作默认为A。
- C：蓝牙扩展与板卡外接显示器的FPGA可视化，负责project/communication、project/visual、host、assets；效果由C设计。音频与显示核心使用FPGA硬件逻辑，不用软核CPU替代；PC/MATLAB只可离线准备素材/测试，或作为蓝牙客户端。
- 首次建档将经过检查的交接基线提交main；后续在任务分支内修改负责范围。常规阅读、可逆编辑、仿真、资料整理不另设批准流程；共享接口/电气连接/板卡顶层更改应在PR写明影响，由A统一集成。用户已明确授权的动作不用重复确认。
- 不能自行替用户采购、下PCB订单、改写板卡Flash、发布正式比赛版本、发送队友消息。远端push按本次任务的授权执行，不把普通本地修改自动视作发布授权。

## 事实与验证

- 2026-09-29：用户已认可audio_core_v1主工程和独立piano16/piano32的音色、效果及复音，见evidence/audio_core_v1_2026-09-29/BOARD_LISTENING.md；audio_core_v2完成八项数字回归、七段RTL参考音及当前源指纹核对：0/3/4/5共享32槽、Warm pluck2物理池12、混合总数≤32，谐波每音固定V1的1/4、拨弦原电平，不偷音、不按活跃数归一化。最坏渲染653/1040时钟，32个不同音高独立相位对照通过；实际矩阵参数下四种闭合相位到非零串行字最坏2.12198ms，非模拟端延迟。唯一可下载入口audio_v2.gprj/audio_v2_top/19 IO；最终50MHz PnR24052 Logic/10684 Reg/66 BSRAM/24.5 DSP，setup/hold 0/0、余量0.632ns。用户对V2完整版本表示总体听感认可，未覆盖模拟SNR/延迟、满载工况或整机验收；见evidence/audio_core_v2_2026-09-29/BOARD_LISTENING.md。新的音频/输入/传输保留接口审计PnR为31075 Logic/15790 Reg/64 BSRAM/24.5 DSP，32个审计IO，setup/hold 0/0、余量0.076ns、约束未命中0；其ADC/host为内部激励，不可下载，不含C显示/蓝牙。精确范围见project/audio_integration/VALIDATION.md和docs/team/RESOURCE_BUDGET_V1.md；SPI ADC、实体控制板及显示/蓝牙整机仍需接入、PnR和实测。packed-bank候选PCM等价失败，默认继续使用V2 stream bank。旧V1/final保持回退。

- 2026-09-28下午音频V1：project/audio_core_v1已采用0→2→3→4→5菜单，八声部，统一host/local/ADC模拟参数服务、真实PCM/832bit快照、ADSR覆盖、两种延音、Lead滑入/弯音/可关颤音、可旁路短房间效果。19针audio_top的最终50MHz PnR为24151 Logic/10918 Reg/42 BSRAM/72.5 DSP，setup/hold 0/0、余量2.562ns；全接口另仅综合审计，非整机PnR。新固件仍待用户板测、SPI ADC/J13/显示/蓝牙未接；先读docs/project/AUDIO_CORE_REVIEW_2026-09-28.md与docs/interfaces/AUDIO_CORE_V1.md。旧custom六项菜单和final回退保留原样。
- 同轮高复音：project/audio_polyphony_lab钢琴16/32共享ROM与算子独立模型、50MHz PnR均通过，4/10 BSRAM、各2 DSP，渲染258/514时钟。安全版16每音固定1/2、32每音固定1/4，不能描述为原电平不变；不用活跃数压音量、不偷音。尚未合并五音色或C、未板测；旧capacity32时序失败只指旧实现。四谐波共相位/包络不能冒充32个独立振荡器。
- 2026-09-28试听决定记录：五音色与四谐波分别调节获用户认可；暂定保留0 Precision harmonic piano、2 Warm pluck、3 Metallic bell、4 Drive lead、5自定义四谐波。ID 1原拨弦退出后续菜单但保留历史源码；禁止静默重编号。当时custom实验仍六项循环、仅记录菜单计划；后续audio_core_v1已采用0→2→3→4→5→0。见evidence/audio_selection_2026-09-28/BOARD_LISTENING.md；final_dual_timbre仍保留回退。
- 2026-09-28自定义音色实验：project/custom_harmonic_lab加入可选候选ID 5；Q8谐波默认[256,64,32,16]、CH0后混音主音量；五路系数/音量以sample_ce平滑更新，四谐波按声部分时计算。EC11在preset5下临时模拟CH0..CH4推子，SPI ADC仍未接入。用户已认可四谐波分别调节的试听效果，不等于实体ADC或所有压力工况板测通过；详情看该目录SPEC/VALIDATION/BOARD_TEST，旧五音色及final基线仍保留。
- docs/project/STATUS.md为当前进度；docs/history是有日期的历史，旧“待上板”或“琴键优先”等建议不能直接沿用。
- 2026-09-26当前决定：final_dual_timbre的harmonic_piano/pluck和实体控制已获用户板测认可；旧原正弦只保留历史诊断基准，不强制作为新产品默认。用户拟增加第三音色、恢复选择性延音/滑音。独立HDMI彩条已实测1920×1080、61Hz稳定，尚未合并音频。B/C按docs/team/RESOURCE_BUDGET_V1.md独立开发；音频80块BSRAM需优化至预算内，不能把目标表当成实测。下面带旧日期的状态按历史范围理解。
- 同日IO修正：B可使用J13 40针扩展口，原PMOD 12根不是B总上限。J13为36根直接信号+2根电阻选择信号+5V/GND；与两组PMOD合计52根直接候选信号。见docs/board/J13_GPIO.md；该结论是资料核对，尚无J13逐针实测，不能把J14/SDRAM1共享排针重复计入。
- 正式规则看references/competition官方PDF；学长指导是非官方建议。用户禁止软核替代核心是项目架构决定，不伪造为官方逐字规定。
- 板卡为Tang Mega 60K基础套餐＋NEO Dock。DK_START官方评估板、138K开发板均不等于本板。显示引脚资料存在差异，查docs/board/DISPLAY.md，禁止直接套用整份参考CST。
- 原instrument正弦DDS＋ADSR 68/6/32768/3是历史诊断基准，AUDIO_TEST_BASELINE.md适用于引用它的旧测试；当前五音色试听默认钢琴见上条。电脑参考音可接受，真实耳机仍有随音高变化的尖锐声，不能写为已修复。
- expression_baseline保留旧自动演示，expression是扩展候选。system v0已有输入适配/配置仲裁/真实meter与快照/独立CDC的数字验证；外设针位/ADC硬件、蓝牙和显示尚未接入。system_top仍只自动演示；旧baseline的meter仍占位。左右样本相同，L/R李萨如只能得到直线。
- system历史共享契约见docs/interfaces/SYSTEM_V0.md；当前音频V1契约见docs/interfaces/AUDIO_CORE_V1.md。旧baseline的retune只改元数据，不能引用为真实变调已验证；system v0已将pitch_we送入DDS。旧8/16声部构建通过、旧capacity32的50MHz时序未通过；后续独立audio_polyphony_lab/piano32已通过，不混用两份实现的结论。
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
