# 2026-10-09 软件收敛验证

角色A，分支`codex/looper-convergence-20261009`，固定比较提交`9d28244`。
本目录是新独立实验；原Looper、refinement和V2的源码、FS及参考音保持不变。
主验收入口及统一操作见[总验收指南](../../docs/project/LOOPER_TOTAL_ACCEPTANCE_2026-10-09.md)。

## 结论与采用决定

最终19针独立候选50MHz/20ns PnR：**33722 Logic / 17592 Register / 23796 CLS / 75 BSRAM / 31.5 DSP**，
setup/hold违例0/0，最差setup余量**0.009ns**，Fmax50.023MHz。
FS SHA256为`c7c3375da9c37929ce959c001712e64f3cddac7bcb51ccec083777f2b404099b`。
与refinement B相比增加256 Logic、517 Register、123 CLS；RAM/DSP不变，时序余量也没有改善。
**不晋升为主验收版**，保留为独立实验对照；明日先验冻结B，不重新构建B覆盖原FS。
1ns余量目标没有达到；零违例不代表模拟音质、晶振容差或整机完成。

完整交付汇总只接受当前源指纹；阶段结果和最终资格分别记录，不使用旧BOARD_DELIVERY作当前依据。

## 数字回归

[当前回归](results/regression.json)42项必测通过，包含35项核心配置和7项独立单元配置。
变化后相关项重跑；7项不受改动影响的单元和已完成的定向事件测试通过源哈希核对后复用本轮结果，
不是拷贝refinement旧PASS。PLL wrapper的行为时钟/Lock失效与epoch恢复模型另通过。

| 范围 | 当前数字结果 | 精确边界 |
|---|---|---|
| 算术/默认音色 | 独立除法302152值；五音色现场/冻结层与原V2共4000帧bit exact | 不证明板卡模拟音质 |
| 32独立相位 | MIDI36..67，混合四谐波音色与全自定义均通过 | 共相位的谐波不另算独立振荡器 |
| 完整期限 | 32旋律＋8鼓＋点击＋房间＋master unity代表场景，max680/1040，peak13707 | 代表压力场景，不是所有参数/频率的穷举 |
| 真实推子服务 | 四根满码归一到92×4；32同音＋8鼓＋点击＋效果，max669/1040，peak13545，无clip | 本轮仍是实体ADC模型，不是实物采集 |
| 超量防护 | 绕过参数服务直接给32同音四系数各256，244帧clip被检测 | 故意越过sum≤368；此PASS不表示该超量音频干净 |
| 存储/生命周期 | 2048事件、串行/并行回放、关闭/撤销/清轨/取消/空录/溢出与token生命周期通过 | 存储事件回放不等于原始PCM录音 |
| 层内表达 | 普通/选择性延音、弯音、层隔离及真实存储→路由→银行往返通过 | 层内控制占128事件额度 |
| 节拍器 | 201档精确期望和40/120/240实际1040 cadence通过，累计拍位≤1sample | 名义时基；无晶振ppm或模拟端测量 |
| 接入 | MCP3208/五推子pickup、25键、54字真实LR1/PCM/ACK跨异步150MHz、epoch恢复通过 | 不含实体ADC/25键/C UI或蓝牙实物 |

2项参考音bench通过，9份WAV重新生成并从PCM回读校验。
[与冻结refinement对照](results/PREVIEW_EQUIVALENCE.json)的9段原始PCM和WAV均逐字节一致，
范围只限这些激励序列，不是所有参数或模拟端等价证明。
单音色/鼓/点击为离线加速干声固定试听增益；组合是N8/P4实际音频核心最终立体声链、房间旁路，
分别保留原电平与固定试听增益。它没有演示完整存储回放或证明32槽期限。
[preview清单](results/preview.json)记录原PCM、WAV、增益、采样率和生成器哈希。

## 接口物理审计与交付门槛

当前最终`registered_ready_50mhz`采用实际50MHz→150MHz PLL wrapper，26审计IO，
最终**2172条网络未布通**，无合格STA/可用FS。
失败放置42303Logic /23548Register /26342CLS /79BSRAM /31.5DSP /1PLLA，PRIMARY/LW仍8/8。
[最终负证据](audit_pll/results/registered_ready_50mhz/FAILURE.json)包含当前输入指纹与`inputs_unchanged=true`；
不是旧阶段的失败报告。上一阶段436条未布网与本阶段2172条不能描述成持续改善。

| PLL审计阶段 | 路由结果 | 资格 |
|---|---:|---|
| pipeline_no_rep_50mhz | 467条未布网 | 失败，历史源 |
| mapped_resets_50mhz | 436条未布网 | 失败，寄存ready前 |
| registered_ready_50mhz | 2172条未布网 | 失败，当前最终源 |

完整collector实际执行返回1，明确拒绝接口失败的完整交付。
显式`--board-only`最终通过42项必测、2项预览、9 WAV、PLL行为模型、两套12路reset映射及106个LF源指纹，
生成[BOARD_DELIVERY](results/BOARD_DELIVERY.json)。该报告`interface_audit_qualified=false`、
`whole_instrument_qualified=false`，**没有合格DELIVERY.json**。这属于验证门槛拒绝，不是用户操作权限问题。

审计额外IO是占位，不可下载，不含C UI/FFT/UART/蓝牙/TMDS；行为模型不代替物理实现。
优化被保留为对照，不能说已解决整合。接下来用C固定源做最小音频＋显示联合构建，
重构声部轨道/弯音状态访问、观察链及高扇出控制，保持C预算而不继续增加大功能。

## 固件包核对

[ACCEPTANCE_PACKAGE](results/ACCEPTANCE_PACKAGE.json)记录本机4份分名SRAM固件及9份冻结refinement参考音。
实际运行包内verify.ps1，13份文件SHA全部通过；主选02改进版，01只作软件收敛比较，03原版和04 V2留回退。
[冻结检查](results/FROZEN_REFINEMENT_CHECK.json)另确认原refinement 102个源指纹、FS和9 WAV未变。
FS/WAV仅本机，提交源码/配置/重建脚本/证据清单；本轮不push远端。

## 实现与独立期望

- 拨弦共享乘积：`x/65536`的向零截断改为算术右移加负数余数修正，
  再利用现有共享乘法器的grant延迟寄存；不额外占渲染时钟。
  `pluck_truncation_tb`使用独立64位有符号除法检查302152个值，涵盖全部低16位余数与signed-min。
  旧绝对值再取负在signed-min溢出，本候选修正该数学边界；该值不属于实际反馈/释放乘积可达范围。
- 状态复制：先寄存256bit分组，再选择16bit写RAM，完整54字复制432时钟约8.64μs。
  LR1字段没有裁减。独立54字oracle覆盖复制中刷新、持有时丢包、随机背压与epoch复位。
  自身选择逻辑减少约73 LUT，但新增256bit寄存器，不能描述成整块或整机资源全面下降。
- 循环事件ready寄存：银行接收后下一sys_clk确认源事件，LOOP_DONE防止源保持valid时重复捕获。
  现场握手保持；循环确认增加一个50MHz时钟（20ns），事件语义/时戳不改。
  路径bench分别计数bank接收和store消费，不再假设二者同周期；两者都必须恰好2次。
- 复位网络：网表逐实例证明有12路物理拨弦slot复位，不是一条复位的12个任意工具副本。
  脚本先综合，逐slot绑定实际别名到LOCAL_CLOCK，再冻结源指纹构建；没有增加STA例外或修改外部针位。

## 物理候选记录

这些是同一目录不同阶段的独立结果；历史源指纹可能与最终源不同，不能拿中间FS冒充最终构建。

| 阶段 | Logic / Register / CLS | BSRAM / DSP | 20ns setup余量 | 采用 |
|---|---|---|---:|---|
| arithmetic_50mhz | 33423 / 17075 / 23743 | 75 / 31.5 | 0.001ns | 向零截断独立对照 |
| pipeline_50mhz | 34032 / 17591 / 23879 | 75 / 31.5 | 0.011ns | 算术/状态流水中间候选 |
| base_reset_50mhz | 同上 | 同上 | 0.008ns | 基础reset路由比较 |
| all_resets_unbuffered_50mhz | 同上 | 同上 | 0.000ns | 12路真实reset路由比较 |
| final_50mhz | 33722 / 17592 / 23796 | 75 / 31.5 | 0.009ns | 增加寄存ready，保留对照 |
| 冻结refinement B | 33466 / 17075 / 23673 | 75 / 31.5 | 0.018ns | **明日主验收** |

上述板级构建setup/hold均0/0；中间文件仅用于定位，统一包只收入最终独立候选和冻结回退。
构建参数/指纹及FS哈希见[最终BUILD](results/final_50mhz/BUILD.json)。详细报告/日志在本机results各阶段目录，默认不提交大报告。
最终PRIMARY/LW仍各8/8。日志有PR1014：sys_clk_d局部路由可能增加delay/skew；STA零违例仍只属于当前构建，
不据此宣称时钟布线已经留出充裕空间。最终关键路径转到银行tracks/loop_bend状态访问，
隔开store握手只是移走了一个瓶颈，没有消除整个观察/控制网络拥塞。

## 保持的范围与限制

50MHz/1040，32共享旋律槽（其中Warm pluck物理12）、另8鼓，4轨×4层×128事件。
不偷音、不按活跃数归一化；四谐波默认[256,64,32,16]，真实服务总系数≤368。
每采样期限、事件容量、独立相位、停止/撤销/清轨、层内表达、ADC/软接管、跨域和恢复分别验证。

实体ADC、25键PCB、C最新UI/FFT/蓝牙/TMDS未合并。审计extra IO是占位，不能下载或照抄接线。
C资源预留不减；CLS、时钟布线和实际联合PnR仍是整合门槛。
板测、满载实际演奏、模拟SNR/延迟待用户；新候选不能继承V2听感认可。
40旋律槽、tap/细分点击没有加入本轮，优先处理已有功能的整合。
