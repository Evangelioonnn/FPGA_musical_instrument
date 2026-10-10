# Looper收敛版 LR1 真实接入契约

这是独立实验接口，不修改既有 SYSTEM_V0/AUDIO_TRANSPORT_V1。A负责最终顶层/约束；C可在独立整合工程使用 rtl/refinement_link.v。未取得C最新显示源；外部时钟审计不含PLL，另有复用已板测显示PLL的audit_pll候选。本轮接口模型通过；独立板及50/150MHz PLL审计的实际资格见VALIDATION。两类审计都不含C的UI/FFT/UART/蓝牙/TMDS，不能称整机完成。

## 域、复位和握手

音频/输入/ADC在sys_clk=50MHz，客户端/观察在observer_clk，测试为异步150MHz。arst高有效；传输桥各域异步断言、同步释放，平台reset_request另同步处理。统一复位丢弃未完成包/命令，消费者按session_start重建状态。sample_ce每1040时钟一拍，Fs=48076.9230769Hz；valid都是握手/使能，不是新时钟。valid&&ready上升沿消费，阻塞时payload保持。

主状态约每1024音频帧发布。声部/来源在音频快照中冻结；平台下一sys_clk捕获Looper附包，因此附包是晚一拍的控制状态，不是所有字段绝对同时。复制期间刷新重启复制并计丢包；观察端持有冻结RAM包时新快照计入state_drops。本轮分级复制每16bit用两个sys_clk，N32完整复制432时钟约8.64μs；相对约21.3ms快照周期仍有余量。整包、drop、序号、背压和session语义保持。禁止逐位同步多位状态。

## LR1状态包：N32、16键、54×64bit

头0x4c52、版本1；不能送给只接受原音频传输头的解包器。state_word_index=0..53，first/last伴随被接收字；先检查头并完整收包再换画面。

| 字索引 | 内容 |
|---|---|
| 0 | {magic16=4c52,version8=1,total8=54,base8=45,ext8=4,keys8=16,reserved8=0}，64'h4c5201362d041000 |
| 1 | 低32序号、高32累计丢快照数 |
| 2..3 | 128bit capabilities，观察总宽更新为2880bit |
| 4..40 | 原V2主状态2368bit：320全局＋32×64声部，最低位先传 |
| 41..48 | 512bit Looper附包，最低位先传 |
| 49..52 | 原256bit扩展 |
| 53 | 低16真实矩阵键位，其余0 |

原字段见 [AUDIO_CORE_V2](../../docs/interfaces/AUDIO_CORE_V2.md) 和 [AUDIO_TRANSPORT_V1](../../docs/interfaces/AUDIO_TRANSPORT_V1.md)。核心旋律mask仍0x3d；鼓模式核心preset0不能当演奏菜单，用附包preset6。

| 附包位 | 含义 |
|---|---|
| 15:0 / 23:16 / 31:24 | magic4c52 / version1 / 旋律槽数32 |
| 34:32 / 37:35 / 39:38 / 42:40 | page / mode / selected_track / 菜单preset（含6） |
| 43 / 44 / 45 / 46 / 47 / 48 | run / count_in / playing / recording / armed / met_enable |
| 56:49 / 64:57 | 请求BPM / 已应用BPM |
| 67:65 / 70:68 / 72:71 | 拍号2..4 / 小节数1..4 / 量化档 |
| 84:73 / 116:85 | loop_tick / loop_number |
| 132:117 / 136:133 | layer_valid[track*4+layer] / muted[3:0] |
| 204:137 | 四轨实际平滑Q16增益，各17bit，轨0最低位 |
| 212:205 / 221:213 / 229:222 | 鼓占用8bit / click_gain Q8 / 本take事件数 |
| 230 / 231 | 锁存fault / clip_seen |
| 263:232 / 295:264 | 路由fault累计 / event_late_count |
| 455:296 | 32×5bit来源，槽0最低位，{is_loop,track[1:0],layer[1:0]} |
| 511:456 | 保留0 |

LR1附包最多32槽；40槽须另起版本，禁止重叠。独立25键生命周期测试不代表refinement_link已接25键；它和下载顶层仍16键，迁移须改适配/keys宽度并回归。

当前drum_active是8个鼓槽占用，不是16垫位图或逐次鼓事件；loop_tick是循环位置，不是独立节拍器的完整全局拍位。C可显示占用数、BPM/开关和循环进度；若要逐垫回放闪光或节拍器停止Looper后的精确拍位动画，须与A补充观察字段后验证，不能靠当前字段声称已经得到这些事件。主音频音量/音色/声部状态仍按上述真实字段使用。

## PCM和命令归属

PCM有符号16bit，是实际PT8211源：旋律房间效果＋鼓＋点击＋固定1/2裕量＋主音量之后。FIFO64帧，满时丢新帧；pcm_index是样本序号，gap表示不连续，session_start表示复位后首帧。gap时重建频谱/波形窗口。房间效果关闭时左右同源，L/R李萨如是直线；开启立体声房间后左右可能不同，但不是两条独立声部振荡器。若需指定两声部的李萨如，应另定义声部观察接口。

命令5bit addr/32bit value/16bit tag，回复addr/value/tag/accepted/applied；合法寄存器沿用V2契约。本地/远端轮转仲裁，直到后端ACK保留owner；拒绝也回相应ACK，远端不会收到本地ACK。applied是目标提交，不表示平滑已到终点。当前远端只配置旋律参数，未支持preset6、Looper/BPM/轨编辑。

## MCP3208与五推子

已知设计器件MCP3208，VDD/VREF3.3V；mode0、500kHz、24bit命令0x060000 | channel<<14，8通道顺序扫描，每1ms请求一组96bit。scan等待ready时保持，忙时跳过新请求并累计adc_skipped。CH0独立主音量；CH1..4混音页控制四轨相对音量，其余页编辑现场谐波。CH5/6摇杆、CH7备用尚未接表达服务。

CH1..4换模式重新pickup，距离≤16原始码或穿越目标才接管，抖动阈值4；外部修改使pickup失效。CH0保留原服务raw0强制静音接管。bundle按sample_ce生效，系数/轨增益平滑。系数Q8默认[256,64,32,16]，sum≤368，四根全推满最终92×4。

仅串行ADC模型通过，实体ADC未接，J13四根针位未冻结。19针固件关闭ADC/remote；audit额外IO是占位，不可下载、不可照抄接线。

## 导入与验收

从lab/audit gprj取得源码闭包，保持目录结构；lab依赖既有正式源，单拷本目录.v不完整。C保持LR1版本检查、整包换帧、PCM gap、命令ACK/tag、复位session语义。

联合PnR须包括真实C源/PLL/时钟、Bank5/Y12电气/针位、最终ADC/控制板。预算见 [RESOURCE_BUDGET_V1](../../docs/team/RESOURCE_BUDGET_V1.md)。实体满载、模拟SNR/端到端延迟另测。

PLL审计复用彩条中50MHz→150MHz/750MHz的原IP配置，仅150MHz有消费者；Lock丢失触发统一epoch reset。实际wrapper的行为时钟/Lock丢失及恢复模型通过，但没有模拟供应商PLL原语或真实锁定时间。将来合C应共用她的同一PLL，不把本审计的1PLL和C的1PLL机械重复相加；若实际配置或源拓扑不同，重新统一约束并PnR。本候选资格见VALIDATION，仍无可用板级针位承诺。
