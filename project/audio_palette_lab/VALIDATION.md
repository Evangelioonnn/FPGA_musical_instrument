# 本轮验证 · 2026-09-26任务（9月27日收尾）

分支`codex/audio-clean-zones`，角色A，起点`d5ee69f`。七份均完成纯RTL仿真、综合及Gowin 50MHz PnR，setup/hold违例均为0。**本轮七份尚未用户上板验收。** 源码/固件哈希与原始测试摘要在[证据包](../../evidence/audio_palette_lab_2026-09-26/results.json)。

## 资源：采用最终PnR计数

| 候选 | Logic | Register | BSRAM | DSP | IO | Setup / Hold余量(ns) |
|---|---:|---:|---:|---:|---:|---|
| 旧final_dual_timbre（已板测） | 12723 | 5459 | 80 | 57 | 19 | 3.473 / 0.191 |
| 00_shared_reference | 12335 | 6594 | 22 | 50 | 19 | 3.525 / 0.247 |
| 01_piano_precision | 12403 | 6718 | 34 | 50 | 19 | 2.365 / 0.247 |
| 02_piano_soft | 13477 | 7021 | 30 | 51 | 19 | 2.733 / 0.200 |
| 03_piano_bright | 13490 | 7018 | 34 | 51 | 19 | 3.931 / 0.196 |
| 04_clean_reed | 12456 | 6720 | 26 | 50 | 19 | 4.316 / 0.194 |
| 05_pluck_detail | 12291 | 6718 | 34 | 50 | 19 | 3.172 / 0.232 |
| 06_pluck_warm | 12826 | 6974 | 34 | 50 | 19 | 2.255 / 0.247 |

00的BSRAM由80降到22（减少58块、72.5%），其中16块是独立拨弦状态RAM，6块是共享ROM；DDS精度候选按所需谐波使用更多表，最多34块。四通道/八槽调度和起音参数共享都已经进入可下载顶层。寄存器略增加是相位/包络快照、Q4路径及区配置锁存的代价。

全部保持八槽、两音色和19IO，PLL为0。对照声音在4582帧中逐样本相等；输入可接收窗口和计算完成时刻有变化，不主张逐fabric拍接口完全等价。1040拍音频周期内，八槽混音104拍（2.08µs）完成；这不是物理按键到模拟声音的总延迟。

A+输入预算70 BSRAM/78 DSP，本轮最多34/51，C的26 BSRAM/16 DSP仍完整保留。预算不因此扩大，最终音频+显示还需重新PnR，不能把两个独立报告相加当整机实测。

## 数字证据

- PALETTE_EQUIVALENCE_TB_PASS 4582 frames: eight voices, mixed timbres, sustain, release, full rejection
- PALETTE_KEYS_TB_PASS full25, config snapshot, same-pitch identity, boundaries, stalls, ghost/overflow
- PALETTE_SCHEDULER_TB_PASS N=1/16, unique outputs, last=114, forced deadline detected
- PALETTE_CONTROLS_TB_PASS volume/left/right/release, clamps, timbre, sustain, panic
- PALETTE_MATH_TB_PASS 14336 profile/phase/envelope vectors
- PALETTE_RANGE_TB_PASS 49 notes C2-C6, back-to-back init, 35/85/127 rejected, frames=217
- PALETTE_BOARD_TB_PASS physical matrix/buttons/encoder, two-zone identity, ghost recovery, 1296 stereo words 1058 nonzero
- 渲染加速对照：0/2/5/6四种数值路径各1000样本，跳过空闲fabric拍与真实1040拍的PCM逐样本相等；初始化保留实际节奏。
- 每份RTL参考151300样本，检查逐帧有效/未知值/溢出/截止；初始静音为精确零。七份真实RTL WAV与匹配参考见下表。保留所有原始样本，不把WAV送回FPGA播放。
- 数学独立参考14336组：整数结果全等；相对连续正弦的抽测最大误差，00约16.93 PCM最低位、01约4.17。是数字查表误差改善，不是板卡噪声测量；没有由此宣布噪声消除。

ModelSim使用纯RTL，不包含器件布局延迟或模拟DAC。`palette_board_tb`模拟无二极管矩阵的连通关系和串行接收；测试bench中的去抖时间缩短以加速，真实下载参数仍为原有值。全49音域测试验证接收、初始化和非零输出，不代替49个音高的实测听感/音准验收。

## 参考音频

| 候选 | 原电平RTL参考 | 首C4 RMS匹配参考 | 峰值 / 首C4 RMS(PCM) |
|---|---|---|---|
| 00_shared_reference | [WAV](../../evidence/audio/palette_00_shared_reference.wav) | [WAV](../../evidence/audio/palette_00_shared_reference_matched.wav) | 5826 / 913.1 |
| 01_piano_precision | [WAV](../../evidence/audio/palette_01_piano_precision.wav) | [WAV](../../evidence/audio/palette_01_piano_precision_matched.wav) | 5835 / 913.1 |
| 02_piano_soft | [WAV](../../evidence/audio/palette_02_piano_soft.wav) | [WAV](../../evidence/audio/palette_02_piano_soft_matched.wav) | 7584 / 1638.1 |
| 03_piano_bright | [WAV](../../evidence/audio/palette_03_piano_bright.wav) | [WAV](../../evidence/audio/palette_03_piano_bright_matched.wav) | 7418 / 1324.6 |
| 04_clean_reed | [WAV](../../evidence/audio/palette_04_clean_reed.wav) | [WAV](../../evidence/audio/palette_04_clean_reed_matched.wav) | 5792 / 967.0 |
| 05_pluck_detail | [WAV](../../evidence/audio/palette_05_pluck_detail.wav) | [WAV](../../evidence/audio/palette_05_pluck_detail_matched.wav) | 725 / 36.7 |
| 06_pluck_warm | [WAV](../../evidence/audio/palette_06_pluck_warm.wav) | [WAV](../../evidence/audio/palette_06_pluck_warm_matched.wav) | 565 / 36.3 |

匹配文件按首个C4的RMS只做衰减：00–04的DDS为一组，05/06拨弦为另一组，用于组内近似同响度比较，不跨组等响；各音色其他音域/和弦的峰值并不保证一样。每声部固定标定，不随活跃数量减小已有音量。05/06去掉原槽的9bit限幅且延后量化，声音可能更响或更有高频细节，需听辨后选择；06的三点滤波会改变高频，不保证比05更好听。

## 构建指纹与复现

| 固件 | SHA256 |
|---|---|
| 00_shared_reference.fs | `99ce65755817d22bc262a1e136437cb8f063f0b2fb05d5487b964eb22e2d30b1` |
| 01_piano_precision.fs | `fa88157b63d71e57d107fd5511f36e74566630e3e79564ea61fe12a101c0e5ce` |
| 02_piano_soft.fs | `0ad7cf4a09b40cd085f9dc12ac35b7e407f27ddba4edeeab72177c94197fd6c9` |
| 03_piano_bright.fs | `480b5252e9e2195d8f907316f3a59933cae76f9e5985c9d800607a4acde7c748` |
| 04_clean_reed.fs | `3bc7122e74e950803195b298102bcf72c253b2b86d5c5a95a2805bc652a41d9a` |
| 05_pluck_detail.fs | `964ab8e6eafa4ff2f8f53055ab3d63985e17e7949c5b038cb67e6c11abe34442` |
| 06_pluck_warm.fs | `a9e1b136b468e1f9b2dc9638a090d61746e2e7a844ea194cc3ecd8b79187f83d` |
| 回退final_dual_timbre.fs | `74e1657ca832e75ee6b99050bca4ee15b08dd49f6ba1a79d92108307ca8313aa` |

构建器要求新FS时间戳、返回码成功、源文件在构建前后哈希相同、时序/资源通过；证据收集再次核对当前源码和FS。复现命令见[README](README.md)。源码通过相对路径复用，不依赖A的绝对目录。

## 留存的限制

- 原50MHz输入路径仍有Gowin PR1014普通布线时钟告警，本轮各候选setup/hold均通过；最终整合应复查时钟路由与实物表现。EX3791位宽缩减中，原拨弦截位保留，新增Q4/谐波缩位已由独立数值参考覆盖；不以“无错误”冒充“无告警”。
- 当前16个实体键是两组白键缩略；完整24/25实体交互、B控制板、压力输入、黑键手感尚未在本轮完成。
- 仍是8槽且满载拒绝新音，不截断旧尾音。没有新增选择性延音/滑音、32声部或吉他效果器。04是干声持续合成音，不冒称真实电吉他模型。
- 不宣称耳机/音箱噪声根因已经定位，原版及所有新音色都需用户试听。未修改旧已板测工程、烧写Flash或合并显示/蓝牙。
