# Looper候选的后续集成边界

本轮没有改正式音频V2接口或C的工程。以下是本实验真实内部信号，不等于已经增加SYSTEM_V0无线帧或屏幕字段；C整合时需在独立顶层接线并重新PnR。

## 来源、域和时序

全部Looper控制、store/router、drum及audio在 `sys_clk=50MHz` 域；内部 `rst` 高有效，启动32时钟。`sample_ce` 每1040时钟一拍；旋律/鼓/点击各有有效脉冲，不能把valid当新时钟。

音频core继续提供V2的 `snapshot_valid/snapshot_data`、`capabilities`、扩展和键位快照；N32时主快照2368bit，现有矩阵键位16bit。其主快照仅覆盖旋律，不包含新鼓的8槽或Looper状态。鼓模式下音频parameter服务维持合法旋律preset0，**屏幕当前演奏模式应使用顶层controls的selected_preset（6=鼓）**，不要把core字段0误标成钢琴正在演奏。

`final_valid/final_left/final_right` 是包含旋律、鼓、点击、主音量和可选旋律房间效果的真实输出PCM；取波形建议用这个节点。RTL现有 `sample_index` 等服务属于音频包；C所需异步状态/PCM桥仍按现有传输契约适配，不能把多位数据逐位两级同步。

## 新状态来自哪里

| 顶层信号/模块字段 | 意义 |
|---|---|
| page/mode/selected_preset/selected_track | 当前物理操作页、模式、完整音色ID、轨选择 |
| bpm，looper_clock_i.active_bpm | 申请BPM、当前已生效BPM；同拍边界更新 |
| meter/bars/quantize/met_enable/click_gain | 拍号、长度、记录量化、可听点击、目标Q8点击增益 |
| tick_in_beat/beat_in_bar | 当前拍内PPQN和小节内拍序0起 |
| transport_run/count_in/playing/transport_recording/record_armed | 播放/预备拍/录音控制状态 |
| recording/record_commit/recorded_events/record_track | store实际录音、提交脉冲、事件计数、录音轨 |
| layer_valid[15:0] | `track*4+layer` 有效层位图 |
| muted[3:0]/track_gains[67:0] | 四轨目标静音和实际平滑Q16增益；每轨17bit |
| drum_active[7:0] / drum.active_pads | 鼓槽占用及对应4bit pad |
| clicks_delivered | 独立点击发生计数 |
| blocked/record_overflow/record_error/operation_error/control_overflow | 输入保护、录音/操作故障 |
| event_late_count/drum_late/drum_rejected/loop_route_faults/loop_unmatched_offs | 拥塞、拒收和路由诊断，不能只显示一个“全部正常”灯 |
| audio_deadline/clip_seen | 旋律截止/削波标志 |

当前board top为避免几千逻辑端口成为物理IO，将观察口留空；整合顶层要把这些内部网真正接到状态打包器，不能靠综合后层次引用。建议音频域按snapshot节拍捕获Looper附包，再用握手/异步FIFO跨域，屏幕一次使用完整包。还须定义新版本号、位图宽度、状态丢包和序号；本轮没有把未定义的新附包冒充正式C协议。

## 控制与内存

当前host端由旋钮/三键的looper_controls占用；以后蓝牙加入需和本地控制仲裁，不能两个模块直接同时驱动host。ADC未接，四真实推子在MIX模式改四轨增益、EDIT模式改现场四谐波；须另外实现模式pickup/标定及owner仲裁，CH0继续后混音主音量。

事件/patch RAM由store持有，回放层不可随现场推子改动。已录patch编辑是后续新功能，不能直接从C时钟域写RAM。音频32共享旋律槽、12拨弦物理池和8鼓槽都包含尾音；Looper层数不是复音容量。

当前资源/CLS/实际STA按 [VALIDATION](VALIDATION.md)及 [预算](../../docs/team/RESOURCE_BUDGET_V1.md)。本候选未包含显示/蓝牙/实体ADC。合并重新做顶层/银行电压/时钟/CDC/满载截止，不相加两份独立报告当整机通过；既有Y12按钮与视频电气冲突也仍按板卡显示说明处理。
