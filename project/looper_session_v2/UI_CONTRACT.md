# LU1 screen/control contract · 2026-10-10

独立候选，不改SYSTEM_V0/LR1。C使用 `session_link`，sys_clk50MHz，observer_clk由C提供；arst高有效，各域同步释放。屏幕/蓝牙无须模拟板载键。命令和回复均 valid&&ready 消费，阻塞保持payload；一个事务在途，tag16原样返回。音频参数地址0x00..0x1f沿用V2，菜单0x00额外允许6（鼓路由，核心preset仍0）；原旋律ID不重编号。

## Actions

| addr8 | value32 | semantics |
|---|---|---|
| 20 | page0..4 | 演奏/Looper/混音/节拍器/自定义；切页不停止循环，mode复位0 |
| 21 | mode0..7 /0..2 /0..3 | 按演奏/节拍器/自定义页检查，Looper/混音只允许0 |
| 22 | track0..3 | 当前轨；录音track在录音请求时另锁存，切轨不重定向当前take |
| 23 | 1 | 启动；已运行拒绝；包括既有一小节预备拍 |
| 24 | 1 | 停止/取消未完成take，幂等；自然尾音 |
| 25 | 1 | 空闲时预备拍+录音；运行时在下一循环边界叠录；满4层拒绝 |
| 26 | track0..3 | 撤销该轨最后层；录音/预备/flush/收尾忙时拒绝，空轨拒绝 |
| 27 | 0x434c5200 OR track | 清该轨，校验确认字；录音/预备/flush/收尾忙时拒绝 |
| 28 | (track<<17) OR Q16gain | gain0..65536；仅相对轨音量，不改主音量，平滑 |
| 29 | (track<<1) OR muted | mute0/1，逐轨，不覆盖其他轨 |
| 2a | BPM40..240 | 下一拍应用，用请求/应用两个字段观察 |
| 2b | meter2..4 | 已运行或已有录制层时拒绝 |
| 2c | bars1..4 | 已运行或已有录制层时拒绝 |
| 2d | quantize0..3 | 关闭/八分/十六分/三十二分；录音或预备/待叠录时拒绝 |
| 2e | 0/1 | 全局点击，不改变Looper运行状态 |
| 2f | click gain Q8 0..256 | 不改轨混音，仍经过主音量 |

所有无关高位必须0（清轨确认字除外），非法值不静默截断。reply_reason8：0成功，1未知地址，2非法值，3状态锁定/忙，4空轨，5层已满，6音频后端拒绝。accepted/applied都为0表示拒绝；成功applied表示目标寄存器或动作请求已提交，不表示音量平滑已完成、录音已经开始、层已清除；查看后续真实状态。实时本地控件动作优先，UI ready暂时拉低等待；不丢命令。ACK反压不堵塞音频输出。复位丢弃未完成命令，session_start后由C重建状态，tag不是跨复位永久去重ID；收到ACK前不要自动重试破坏性动作。

## LU1 status

32bit流，共23字：word0=0x4c550117（LU/version1/count23）；word1序号32；word2累计丢快照数；word3..22为640bit/20word payload，最低字先传。index5，first/last/session_start伴随valid字。每256音频帧发布（约5.325ms）；阻塞时丢新快照并计数，发送中的整包冻结。C仅在完整合法包收齐后更新界面，独立于画面VBlank换帧。复位扔掉半包。

| payload word | contents |
|---|---|
| 0 | page[2:0],mode[5:3],selected_track[7:6],menu_preset[10:8],run11,count_in12,playing13,recording14,armed15,met_enable16,fault17,clip18,clock_run19,record_busy20,flushing21,muted[25:22],has_layers26,record_track[28:27] |
| 1 | requested BPM[7:0],applied BPM[15:8],meter[18:16],bars[21:19],quantize[23:22] |
| 2 | loop_tick[11:0],tick_in_beat[18:12],beat_in_bar[21:19]，拍编号从0开始 |
| 3 | layer_valid[15:0] (track*4+layer),loop_length[27:16] |
| 4 | authoritative master target Q16[16:0],master owner[18:17],audio fader pickup[23:19] |
| 5 | authoritative applied master gain Q16[16:0] |
| 6..9 | four applied smoothed track gains Q16 low17 |
| 10 | applied coefficient0/1/2，各9bit，从最低位顺次 |
| 11 | coeff3[8:0],release[11:9],glide[14:12],signed bend[19:15],sustain20,sostenuto21,FX22,vibrato depth[29:23] |
| 12 | physical matrix keys[15:0],active drum pad mask[31:16]（从真实8槽归约，不是独立16声部） |
| 13 | drum accepted-strike counter[15:0],last_pad[19:16],track[22:20],layer[24:23] |
| 14 | loop_number32 |
| 15 | take event count[7:0],active drum slot mask[15:8],mixer fader pickup[19:16] |
| 16 | UI result sequence[15:0],last action addr[23:16],reason[31:24]；仅UI后端动作更新，音频动作或dispatcher未知地址拒绝不更新；详细tag/参数走ACK |
| 17..18 | harmonic raw targets1/2与3/4，各12bit，低位先；未接实体不当原始位置显示 |
| 19 | drum late/拒收、router故障和late的标志低4；其余保留 |

鼓strike counter可检测同pad重复敲击，但不含整段逐垫历史；瞬态动画按差分并参考last_pad，不声称所有同时事件均可重建。全局拍位由真实clock提供，停止Looper而点击继续时仍更新。beat_pulse动画可由tick回绕推导，丢快照时仅更新当前位置。keys仍16键：25键/36键控制板未接入本候选；换矩阵必须另起接口版本/明确扩宽。

PCM接口沿用16bit立体声、序号、gap和session语义，取实际后混音/主音量PT8211源。默认只接LU1；`WITH_FULL_STATE=1`另启用原LR1详细声部状态，必须另外预算并做联合PnR。LU1与LR1不可混用解包器。交付仅逻辑接口，无HDMI顶层或C显示实测。

master/track gain均Q16（65536=1.0）。四谐波系数为Q8（256=1.0），默认[256,64,32,16]，原始推子目标12bit；参数服务做归一化与平滑，不把原始12bit直接当Q8。master owner：0初始/复位、1本地、2主机、3实体ADC接管；audio pickup五位分别CH0..4，mixer pickup四位分别轨0..3。word0的busy20包含record_busy与事件存储收尾/编辑忙，不只有“正在录音”。release/glide/bend等单位和作用遵循[AUDIO_CORE_V1](../../docs/interfaces/AUDIO_CORE_V1.md)与[V2](../../docs/interfaces/AUDIO_CORE_V2.md)，菜单6是本候选额外鼓路由。

raw源快照`ui_snapshot_valid`是sys域单周期发布脉冲，数据保持至下一发布；流端`ui_valid`则遵循valid/ready保持协议。原始诊断计数ui/state/pcm drops及ADC skipped仍在sys域；C消费LU1包word2/PCM gap，而非直接跨域读这些计数，详见C_HANDOFF。
