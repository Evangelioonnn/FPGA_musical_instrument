# 改进版数字与实现验证

分支codex/looper-refinement-20261007，比较commit0199ed7；用户尚未板测本轮或旧Looper，不替换已认可audio_core_v2。collect_evidence.py核对当前源码、构建、FS、原PCM和WAV。最终结果是 [BOARD_DELIVERY](results/BOARD_DELIVERY.json)：独立19针候选合格、接口审计未合格、整机未合格。严格完整collect已因真实路由失败而拒绝，不生成DELIVERY.json。缺结果/指纹不同/STA失败不能成为PASS。

## 当前19针候选

Gowin V1.9.12.03、GW5AT-60B/GW5AT-LV60PG484AC1/I0；looper_refinement_top，50MHz/1040。保留32旋律（含12拨弦）、另8鼓、4轨×4层×128事件、冻结patch、表达录放、短房间、全局点击、矩阵/EC11/三键。

| 项目 | final_50mhz |
|---|---:|
| Logic / Register | 33466 / 17075 |
| CLS / BSRAM / DSP | 23673 / 75 / 31.5 |
| 实物IO | 19 |
| SDC周期 | 20.000ns |
| Setup/Hold违例 | 0 / 0 |
| 最小setup余量 / Fmax | 0.018ns / 50.044MHz |

FS SHA256：ce06b7105a62f311cabbab9cb972bef0f680282afb895f4fb799b025f8828a3d。

最小余量非常薄，不能承诺合C后通过。PR1014等时钟路由提示须随整机继续检查，PRIMARY/LW计数不是实际时钟域数量。额外18ns guard在同功能源上失败，21 setup端点、最差-0.466ns；保留results/final/BUILD.json为失败历史，不能把其FS当通过版。20ns build为实际验收，结果不能用18ns报告Fmax替换。

## 资源优化与等价范围

固定旧Looper为32251Logic/16254Reg/22780CLS/86RAM/33.5DSP。ROM-only阶段32600Logic/16262Reg/22805CLS/74RAM/33.5DSP：精确quarter表省12RAM，保持4096地址精度、四读通道和一拍延迟。新增表达/其他优化后的完整候选75RAM，相对旧版净省11RAM；geometry预计算减少2DSP，但Logic/Reg/CLS有增加。不能声称所有资源都下降。

旧64bit事件的19bit保留原已被综合裁掉；45bit声明清理不单独算RAM收益。未采用有PCM差异的packed-state优化。

`tools/profile_synthesis.py`提供可复现综合层级分析，结果在results/SYNTHESIS_PROFILE.json；board/external audit/PLL audit的逐层自有Register相加均与供应商根T_Register一致，126项RTL指纹核对通过。外部审计state_bridge有2545 LUT，waveform约291 LUT+7 ALU，commands约223 LUT+5 ALU；PLL审计自有LUT+ALU对应2550/301/228。应先优化完整快照的选择/复制及bank状态访问，而不是把PCM传输当主要负担。这是综合排名，不是PnR Logic/CLS/物理BSRAM分摊，不能将层级总量重复相加。

五音色默认参数的现场与冻结循环各对照原V2单槽bank，合计4000帧比较；这是默认bank PCM，不是所有动态参数/32满载/模拟输出都逐样本等价。新Looper和旧Looper均固定后混音1/2裕量，较原V2单旋律低6dB。

## 必需回归

sim/regression_cases.py为唯一矩阵：40项mandatory（含5个unit配置）＋2个预览bench。regress.py --resume只复用当前源码SHA一致PASS，--exclude写partial，不可替代完整regression.json。每项JSON记录bench和依赖指纹。

| 类别 | 验收 |
|---|---|
| 节拍 | 40/120/240一分钟模型；201档逐拍独立数学期望；实际1040周期代表档；非零PCM点击/重拍；下一拍调速/关闭相位保持 |
| 存储/生命周期 | 4轨16层2048事件，原并行及生产SERIAL_NOTES路径都满容量重放/随机背压；边界排空补松/取消/撤销/清空/原子溢出 |
| 表达 | 实际core→store→router→bank：8控制4音符事件；层隔离/选择性子集/现场踏板污染无效/弯音；425独立DDS递推；初始3控制空录不占层 |
| 时间戳 | 早音符/晚表达FIFO的合并排序；稳定背压/无重复/无死锁；溢出取消后下一take可重试 |
| 声部 | MIDI36..67独立十二平均律/相位；混合四谐波音色/全custom32；不偷音、不按活跃数归一化 |
| 满载 | 32旋律＋8鼓＋最大点击＋房间＋master unity，真实1040周期；整链最大渲染680/1040，代表场景峰13707 |
| 四推子全满 | 实际服务sum368、92×4；32同音＋8鼓＋最大点击＋房间，峰13545、669/1040，无clip/超时 |
| 非法注入 | 绕过系数服务向bank注入256×4，N32应报告clip；这是负向诊断，不是正常推子条件 |
| 实物顶层模型 | 实际扫描到PCM、六项菜单、鼓/旋律录放、停止清映射、独立点击；循环tick加速/force，音频1040；不替代真实BPM测试 |
| 输入 | MCP3208默认500kHz/1ms和加速串行模型；模式/pickup/owner/背压；25键48..72、双区移八度/切音色不重触发held、原token松键 |
| CDC接入 | LR1真实54字/真实PCM比较、本地/远端ACK归属、随机ready、PCM满FIFO丢样及gap；异步复位丢半包/旧命令/PCM session恢复 |

40项必需回归已在当前源全部PASS，最终独立板资格由results/BOARD_DELIVERY.json核对；接口路由失败阻止完整资格，不能沿用旧38项或旧源结果。ModelSim精确数组仅用于仿真，每次独立对照生产case ROM全部地址/XZ/随机跳址；生产GPRJ仍literal quarter ROM。

## C接口/ADC审计

refinement_link是真实ADC→五推子→参数/混音→平台→状态/PCM/命令CDC；observer异步150MHz。audit/refinement_audit_top为27个占位IO，只用于保留接口资源/时序，**不可烧录**。真实UI/FFT/UART/蓝牙/PLL尚未含入，不能称完整C整机。

18ns审计出现PR0004、300未布通网络；失败放置资源40955Logic/22648Reg/26364CLS/77RAM/31.5DSP，不能当通过PnR。实际50MHz/20ns默认审计也失败333网，40955Logic/22648Reg/26378CLS/77RAM/31.5DSP；两次FAILURE.json记录各自约束指纹。

报告中基础voice_rst及多个副本被提升到PRIMARY，PRIMARY/LW均8/8，不表示八个真实时钟域，也未证明这是所有失败网的根因。依据SUG1018-1.7E第2.7节，对基础voice_rst使用audit-only LOCAL_CLOCK，失败272网；基础网退出PRIMARY，但副本继续自动提升，资源不变，不能将未布网减少当作通过。

另建audit_pll/26占位IO，复用已板测彩条的Gowin PLL，配置50MHz→150MHz观察域，lock丢失触发统一epoch复位；生成时钟约束指向PLL输出，保持所有跨域限时。最终 [PLL审计失败](audit_pll/results/pll_50mhz/FAILURE.json)：3402未布网，放置41005Logic/22760Reg/26449CLS/79RAM/31.5DSP/1PLLA，PRIMARY/LW各8/8。没有合格FS，未运行完整STA，不能确认生成时钟及跨域约束的最终命中/时序资格；配置和模型频率不等于物理时序通过。

实际PLL wrapper/harness的行为时钟模型 [CLOCK_MODEL](audit_pll/results/CLOCK_MODEL.json)通过未锁定启动、失锁epoch复位和恢复PCM；不模拟供应商PLL原语或真实锁定时间。四次尝试均不含C UI/FFT/UART/蓝牙/TMDS，均不可下载。完整collect拒绝已实际核对；显式--board-only仍要求40项必测、2预览、9 WAV、全部当前输入/FS/PCM指纹和本次真实失败证据。所有尝试保持功能RTL和STA检查，没有放松约束或忽略未布线。

## 参考音

preview.py已生成9个WAV：五音色、16鼓垫、120BPM点击、arrangement_fixed及arrangement_audition。干声为N1/P1、CE64；完整混音预览用实际core N8/P4、CE256离线加速，包含鼓/点击/层表达/轨音量渐变/Lead滑入，房间模块在链路中但当前试听旁路。开启房间的验证另由满载bench覆盖。初次CE512长预览2400秒、干声1800秒超时，不算PASS；最终两段当前源预览均在4800秒限时内PASS。

fixed保留整链原PCM；audition逐文件一个固定增益，不按声部数归一化。WAV元数据48077Hz，逻辑Fs精确50000000/1040；conversion逐字节回读，manifest记录原峰值、增益、帧数、PCM和WAV SHA。它不回灌FPGA，不是32槽期限/存储回放全部路径/模拟声音证据。

## 仍需验收

板上音色/鼓/过渡/录放操作、模拟SNR/延迟/杂音根因、实体ADC/五推子/25键、C UI/FFT/蓝牙整机。开放镲空槽淡出约10.7ms，满池choke可重置被choke槽，可能有突变，待试听。长弯音控制也占128事件，容量不足取消take；不是无限自动化。40槽/tap/细分延后，理由见WORK_PLAN。C预算不减，CLS容量和实际联合STA必须另审计。
