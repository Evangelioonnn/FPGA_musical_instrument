# 音频共享接口 V1 · 2026-09-28

生产者是[project/audio_core_v1](../../project/audio_core_v1/README.md)，A负责实现和适配；
B/C可先用mock独立开发。此契约不覆盖历史SYSTEM_V0位布局，也不是蓝牙线协议。
当前板级 `audio_top` 只有19 IO，主机/ADC置空闲，观察端未接显示；
下列端口在 `audio_core` 和全接口综合审计中保留。

## 时钟和输入

全部端口属于 `clk=50MHz`，同步高有效 `rst`。`sample_ce`为单时钟脉冲，固定每1040时钟一次。
当前主版本只验证 `N=8`，不应只改N就宣称16/32五音色通过；钢琴高复音有独立接口。

`keys[KEYS-1:0]` 是去抖后的完整逻辑键快照，`changed`单周期发布。
`ghost`和 `all_released`须来自实际扫描；故障后必须全部松开才重新接受击键。
完整25键用 `KEYS=25 / SPLIT=12 / DIATONIC=0`，左键0..11、右键12..24各自加音区MIDI基址。
现在实物顶层为 `16/8/1`，每区8白键。移区只改变新击键，松键保留原token身份。
音域允许MIDI36..84；矩阵按键不等于声部上限。

底板 `button_n[2:0]`低有效、EC11 `step_valid/step signed[1:0]`已完成同步/去抖适配。
step只发±1；编码器按压未确认，不接悬空C脚。
最终输入PCB可替换这些测试适配器，A/B逐模块确定RTL归属和针表。

## 配置与ADC

`host_valid/host_ready/host_addr[4:0]/host_value[31:0]`采用标准保持式握手。
valid/ready同高的上升沿捕获整份请求；生产者在握手前保持payload，握手后可改。
local与host同时活跃时交替接收；合法目标在sample_ce提交。

`ack_valid`单时钟脉冲，无背压。`ack_source` 0=local、1=host；
`ack_addr/ack_value`回传请求及规范目标，`ack_accepted/ack_applied`合法时均1、非法时均0。
这里的applied指目标已提交，**不表示音频平滑已完成**；远端应结合实际值回读。
所有主机请求应在音频域经队列进入，不能让UART或显示消费阻塞音频。
地址表、默认值及pickup的完整定义见[参数服务SPEC](../../project/audio_parameter_lab/SPEC.md)。
关键单位：主音量17bit Q16、0..65536；弯音有符号±8、每格0.25半音；
ADSR为每PCM帧的幅度码变化；效果mix为Q8、0..128=0..50%，不是Q7满湿。
ID1及未实现参数必须NACK，不能回报成功。

`adc_valid`是单周期扫描发布脉冲，只有 `adc_ready`高时才发；
`adc_ch0..4[11:0]`须是同一轮采集的完整组。超限整组丢弃、sticky overrun；不逐路更新。
CH0对所有音色控制后混音主音量；CH1..4只在选中ID5时接管自定义系数。
pickup在位置接近或跨过目标时接管，主音量实体零点始终静音。
实体8通道12bit ADC的4根SPI线、模式/速度及J13球号未冻结，此契约不是SPI针级协议。

## PCM与波形

`final_valid`单周期发布，`final_left/right`为有符号16bit PCM，范围-32768..32767，保持到下一次发布。
取样节点为声部混音→短房间效果→主音量后的实际送DAC样本；不含模拟DAC/功放影响。
`sample_index[31:0]`与该样本对齐，是真实1040节拍的序号，按32bit模计数，不是只统计成功发布数。
正常每节拍一组输出；panic清银行和效果时可中断一次零PCM更新，序号出现间隔。
板上发送器在间隔保持零样本；C应识别丢样/复位，不把不连续样本拼成连续FFT窗口。

没有PCM背压。C的FIFO满时应丢弃观测帧/标记缺口，并保持发声运行。
FFT取全速PCM，双声道至少携带共同sample_index；可选择左或明确标记的 `(L+R)/2`，后者用17bit中间值。
抽取波形可降采样，FFT降采样须先低通；不能直接拿未滤波抽取流解释全频谱。
单声道原始16bit流约96.15kB/s，双声道约192.31kB/s，另加序号和协议开销。
当前干声L=R；房间湿声启用时才提供真实不同的左右样本。不要用干声伪造立体声李萨如。

## 状态快照

`snapshot_valid`单周期，`snapshot_data`总宽 `320+64*N`，N8时832bit。
每1024次实际PCM发布一份，正常约46.95Hz。快照在一个音频时钟沿整体捕获，输出寄存器保持到下一份。
它是该时刻状态与刚完成电平窗口的记录，不是每个字段都反映相同历史音符的录音元数据。
快照头不内嵌PCM序号；若要关联波形，在50MHz源域将快照发布时保持的 `sample_index`
一起锁存后跨域，不能用snapshot_sequence×1024推算，panic期间可能缺少一次零更新。
端口无背压、无内置跨域：C用握手锁存或真正异步FIFO传整个bundle，不能逐位两级同步。
握手发送寄存器必须在对侧确认前保持不变；忙时可合并/丢弃中间显示快照并用序号识别跳过。

### 320bit头部

| 位 | 字段/单位 |
|---|---|
| 31:0 | snapshot_sequence，首次0 |
| 63:32 | parameter_revision，接受配置/实际ADC目标变化后递增 |
| 80:64 / 97:81 | master target / applied gain，unsigned Q16，0..65536 |
| 100:98 | 新击键的selected preset ID |
| 101 / 102 | ordinary sustain / selective sustain |
| 103 / 104 | 新击键ADSR override / custom_hold |
| 105 / 106 / 107 / 108 | effect enable目标 / clip sticky / deadline sticky / key blocked |
| 113:109 | 当前面板旋钮模式，0..16；custom只有0..4 |
| 120:114 / 127:121 | 左/右区MIDI基址 |
| 130:128 / 133:131 / 138:134 | release index / glide index / bend signed5 |
| 145:139 / 148:146 | vibrato depth target / speed index |
| 156:149 / 165:157 | effect mix target8 / wet applied9，均Q8 |
| 201:166 | `{c3,c2,c1,c0}`，各9bit Q8；c0为基频 |
| 233:202 / 265:234 | rejected note count / input fault count，32bit |
| 281:266 / 282 | 最近1024有效PCM峰值（左右较大绝对值） / 窗口clip |
| 283 / 284 / 285 | ADC overrun / harmonic overrun / panel overflow，sticky |
| 290:286 | fader_acquired CH4..CH0 |
| 291 / 292 / 293 / 294 | room ready / muting / reserved0 / reset gap pending |
| 310:295 | stream_reset_count16，panic清银行时递增 |
| 312:311 | master owner：0默认、1local、2host、3fader |
| 319:313 | applied vibrato depth7 |

clip是混音/效果饱和诊断（主音量不会大于1），不是模拟削波传感器。
clip sticky只在系统rst清零；deadline及rejected count在银行/效果panic reset也会清零。
fault count只在系统rst清零；读取这些字段时结合stream_reset_count。
未暴露完整ADSR目标、raw系数或Lead起音索引的通用远端读协议；新增字段要版本化，不能挤进保留位后不告知C。

### 每声部64bit

声部i从 `base=320+64*i` 开始：

| 相对位 | 字段 |
|---|---|
| 31:0 | strike token32，occupied=0时不可解释为有效音符 |
| 38:32 | MIDI note7 |
| 41:39 | 该声部自己的preset ID，不是全局新音色 |
| 42 / 43 / 44 / 45 | occupied / physical held / gated / sostenuto latched |
| 61:46 | DDS/铃音当前包络16bit；Warm pluck不适用，值为0但不表示其声音为0 |
| 63:62 | reserved0 |

occupied包含尾音占用，held只表示仍按住，gated表示未进入释放；Warm pluck的实际尾音不由held长度决定。
held属于占用声部；若要画所有实体按键（含满载拒收或自然结束的按键），还需单独传逻辑keys快照。
声部token/音高等可能保留空槽上次值，显示必须先检查occupied。

## 集成条件

A+输入预算29k Logic/17k Register/70 BSRAM/78 DSP；C保留26 BSRAM/16 DSP。
当前19针主版本PnR通过，另有全接口综合审计；**尚无显示+蓝牙+新ADC整机PnR**。
Bank5音频J16与TMDS电气属性及Y12用途须按[显示事实](../board/DISPLAY.md)统一后合并CST。
不用另一套未测DVI球号，不额外抢占B的J13预算。
端到端≤10ms/≤5ms指标要按输入触发到模拟输出实测；内部算术或CDC耗时不替代它。
