# 旋钮演奏与控制验证

角色 A，分支 `codex/knob-performance-suite`，基线 `7a9ac41`。这里将已经上板通过的 EC11 解码接入独立音符、复音和参数控制；不是已经验收的整机。任务契约见[SPEC](SPEC.md)，最终证据见[本轮记录](../../../evidence/knob_suite_2026-09-20/README.md)，上板操作见[早上验收](../../../docs/project/KNOB_REVIEW_2026-09-20.md)。

首次板测已反馈：音量/释放控制认可，基础弹奏有效，但快转新音起音有新增大噪声、转动切换音色时有延后附加声；本轮电脑参考没有这些异常。完整事实与下项诊断见[板测记录](../../../evidence/knob_suite_2026-09-20/BOARD_LISTENING.md)，不把这些固件标成音质已验收。

## 五个入口

| 工程 | 顶层 | 旋钮作用 | 发声来源 |
|---|---|---|---|
| [performance](board/performance/knob_performance.gprj) | `knob_performance_top` | 每格触发一个独立音符 | 16声部原参考音色，上电静音；静止后已有声音自然结束 |
| [volume](board/volume/knob_volume.gprj) | `knob_volume_top` | 0..24音量档，端点饱和 | 原音色自动音符/四音和弦；0静音，24原电平 |
| [timbre](board/timbre/knob_timbre.gprj) | `knob_timbre_top` | 原音色→pluck→FM循环 | 每0.5秒一个音，8个可分配声部；旧音保持原音色 |
| [release](board/release/knob_release.gprj) | `knob_release_top` | 改变下一次音符的释放时间 | 每1.2秒弹C4，持键0.2秒；其余ADSR仍原参数 |
| [echo](board/echo/knob_echo.gprj) | `knob_echo_top` | 0..16档回声量 | 每秒弹C4；约85.2ms延迟、固定1/2反馈、干声增益始终1 |

五个工程都是7个物理IO。下载使用各目录 `impl/pnr/knob_<名称>.fs`，只作SRAM试听。打开或重新打开Designer后核对上表顶层；禁止选择bank、slot等内部模块。构建产物本地保留，Git提供源文件与重建脚本。

## 当前接线和边界

沿用[已板测的四线接法](../ec11_probe/README.md)：3.3V、GND、A→T18、B→R17；C悬空。拔下PMOD-LEDx8，避免和编码器共用针脚。没有新增接线，没有绑定按压或踏板。正负方向以原解码器为准，不预先承诺顺时针必然加大。

旋钮弹奏版初始选音C4，每正向一格升一个半音并弹奏，反向降一个半音并弹奏。范围C3..C6，边界继续旋转会重弹边界音。每次都是独立实例；同音不合并，重复弹奏不截前一个尾音。

基准持键31250采样≈0.650秒，随后release_step=3、从32768自然释放，约0.227秒。占用声部约0.877秒加少量启动/排空周期。16声部是有限容量：满载拒绝新的触发，已有音继续；`rejected_count`记录拒绝。FIFO溢出另有`queue_overflows`。当前板级无显示，这些计数仅在逻辑/仿真接口可观察，不能宣称实物已显示过载。连续均匀触发的理论容量约18格/秒，突发也需有空闲声部；这不是任意快转都不漏音的保证。

原音色直接实例化原 `synth_voice`，不除以活跃/最大声部数。16个同相最大幅度的数字界限约±8192，仍在16位PCM内。FM/pluck各自固定除32并保留既有监测限幅，声音随音色选择变化，增益不随声部数变化。电脑预览固定×8，不能据此推断实际耳机声压。

音量1..24为-69..0dB的3dB步进，0静音；每个采样增益最多变化128/65536，满量程平滑约10.65ms。已有低电平监测信号在最低若干档可能量化为0或少量码值，不应将档位数误认为同样多的有效DAC位数。该平滑完成时间也不等于输入到声音开始变化的延迟。

释放档位0..7对应step 96/48/24/12/6/3/2/1；默认档5。对本演示的保持电平，尾音约7/14/28/57/114/227/341/682ms。参数按新音符锁存，旋钮不会改写已经发声实例的尾音。音色/释放切换恰与自动触发同周期时，本次触发使用更新前配置，下一次采用新配置。

## 复用与验证

- `knob_bank`/`knob_slot`：独立实例、自动松键、普通/选择性延音逻辑、全释放、固定电平混音。与旧system按音高合并身份不同；没有静默改动旧共享接口。
- `knob_controls`：旋钮映射与事件队列；不同模式独立固件，无假定的按压输入。
- `knob_gain`/`knob_effect`：独立数值期望验证。效果量0返回精确干声；延迟线持续运算，恢复效果可能听到已有历史。
- `knob_reference_voice`：默认直接调用原voice，释放实验才使用动态ADSR伴随实现；默认逐样本回归和独立包络模型分别验证。
- `knob_pitch`：独立滑音/弯音逻辑测试，接到原DDS验证实际相位；**没有接入这五份板级固件**。base_step和Q16弯音经过一拍乘法，配置在下一个可用采样边界生效；弯音限制0.5..2，音高限制奈奎斯特以下。

FM/pluck的单声部算法复用原实现。拨弦新增可选 `LOGIC_SCALE=1`，用 `8192−256−64−8` 实现乘7864，默认0保持旧实现。该优化与默认版本逐样本/握手比较，在新三音色构建中节省8个DSP。原单声部工程继续使用默认0，历史构建报告仍只对应其当时源码指纹。

仿真覆盖16个同音独立完整包络、八个混合音色与独立单声部求和、踏板捕获、非法请求/满载恢复、配置队列、数字增益/延迟、实际PT8211串行解码。独立Python数学模型对完整逐格演奏的384616样本逐个验证，包含20次触发、最多9个可闻实例，没有读取RTL查表或复用渲染单声部充当期望。

默认渲染压缩采样间空闲系统周期，并将volume/release/echo的空闲池缩为4/2/2；performance仍16、timbre仍8。拨弦初始化帧保留1040周期。五段结果与初始完整池渲染逐字节一致，来源边界见证据目录。真实50MHz/1040、完整物理声部配置由短传输bench覆盖；该短检查尚未到达下一次自动音色事件，新的FM/pluck由multi/render验证。

```powershell
# 从仓库根目录执行；换成自己电脑工具路径。
& ./project/input/knob_suite/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'
python project/input/knob_suite/tools/export_audio.py
python project/input/knob_suite/tools/performance_oracle.py
python project/input/knob_suite/tools/build.py
python project/input/knob_suite/tools/record_evidence.py
```

可用 `-Benches 'bank_tb,multi_tb'` 选择检查，`-RunDirectory work_other`将库和输出都放到独立目录；导出/记录脚本相应传 `--sim-dir project/input/knob_suite/sim/work_other`。不能同时编译/运行同一个库。`-FullPools -Benches 'render_tb'`可重跑16/16/8/16/16配置，耗时明显更长。`create_projects.py`重建工程配置及音量查表，`knob_pitch`没有板级绑定，因此不列入这些gprj。

原尖锐杂音仍未定位；本次数字验证、布局布线和电脑WAV不替代新固件的耳机板测、模拟频谱或比赛端到端延迟测量。
