# 音符事件与声部状态 · 现有RTL参考

> 历史契约，仅用于本页对应旧工程。当前C对接先读[AUDIO_CORE_V2](AUDIO_CORE_V2.md)、[传输契约](AUDIO_TRANSPORT_V1.md)和[接口索引](README.md)；下文“当前/新”均指当时版本。

所有端口同步到50MHz，`rst`高有效。异步物理输入先同步/去抖，其他时钟域走正确CDC。仅在`event_valid && event_ready`的上升沿接受一条；等待时必须保持所有字段。持续valid不是“持续按住”。

| 字段 | 位宽 | 含义 |
|---|---|---|
| event_kind | 2 | 0 note_on、1 note_off、2重定音、3保留 |
| event_note | 7 | 0..127音符身份，A4=69，不表示已实现MIDI电气协议 |
| event_value | 7 | kind=2时的新目标音高，其余忽略 |
| event_velocity | 9 | note_on线性幅度0..256；>256钳位，0按松键处理 |

持键变调示例：on身份60 → retune身份60到67 → off身份60。**更正旧结论：旧baseline只更新音高元数据，baseline_voice把pitch_we固定为0，真实DDS不随retune改变。** 新system v0把重定音送进真实相位累加器，已有实际步长检查，不重置包络/相位、不新占声部；仍未启用expression的平滑滑音/全局弯音。

和弦逐条排队发事件。输入适配层必须处理多个物理键映射同音、持键切布局/八度和不同输入源；当前核心以note作为身份，不自带物理键/source_id。需要同音独立发声时要升级契约，不能假定现有端口已经区分两个同音键。

`occupied`包含释放尾音；`held`表示仍按着；`gated`包含踏板保持；`sost_latched`表示选择性延音锁存集合。声部槽不是固定键号。`notes/pitches`每槽7bit，`voice_samples/envelopes`每槽16bit，`steps`每槽32bit，槽0在最低位。N默认8，不应把显示/通信写死4路。

`stolen/ignored`是诊断事件，应记录以便排查。新[system v0](SYSTEM_V0.md)已有音符FIFO、实体输入快照满队列恢复、配置来源仲裁的数字实现；真实外设绑定、BLE断连和多音符源身份仲裁仍未完成。旧baseline本身没有新增这些保障。
