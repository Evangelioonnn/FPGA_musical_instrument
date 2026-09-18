> 2026-09-19交接状态：电脑16秒演示及默认音色暂获认可；实际耳机仍有随音高变化的尖锐声，真实交互未接入。 最新总状态见[STATUS](../../docs/project/STATUS.md)。下文保留原实现/验证过程；sim音频、impl比特流和manifest等本机产物不随Git提交，需重新运行脚本，精选证据见[evidence](../../evidence/README.md)。旧指纹不能当作当前文件指纹。

# 统一基准音色功能测试

2026-09-18：按用户“直接在这个版本上修改、全部使用原类似钢琴音色”的要求修订本工程。所有声部直接使用原 `instrument/src/synth_voice.v`，数学正弦 DDS、ADSR=68/6/32768/3。满力度、满音量的单音恢复原 instrument 电平。用户规则见根目录 `AUDIO_TEST_BASELINE.md`。

## 本轮修正

- 基准音色不经过 `expressive_voice` 的谐波、滑音流水线；力度256时保留原样本，64/128分别缩放至1/4、1/2。
- 专用 `baseline_mixer` 全宽求和、Q16总增益和最终16位饱和，不按最大声部数除以8。输入样本与增益一起锁存。
- 音量演示后留出完整尾音，三档力度均从已释放状态开始；四音和八音展示之间也留出释放时间。
- 选择性延音的新A4持键0.3秒；四音递增时最后的C5持键约0.26秒。八音改为C3/G3/C4/E4/G4/C5/E5/G5，避免密集音阶和弦干扰音色判断。
- 修正旧测试：统计真正的声部数量，事件压缩后仍保留所有松键事件，失败时严格报错。

乘法写法本身未被证明导致旧失真，原低幅度样本也不会使16位求和溢出；显式位宽和全宽混音是计算边界保障，不把它们冒充已定位的杂音原因。

## 当前下载文件

- 工程：`project/expression_baseline/expression_baseline.gprj`。
- SRAM下载：`project/expression_baseline/impl/pnr/expression_baseline.fs`。
- 生成时间：2026-09-18 18:23:13（本机时间），大小17,819,587字节。
- SHA-256：`4A3BBD132234E69E9D0F87607F85F25BB5AAFE0D105E0648DAA8CD45EBCC3723`。

Programmer重新选择上述文件，按原已验证方式下载到SRAM。接原耳机即可，顶层沿用原音频引脚；下载后自动循环约16秒。无需新建项目或改线。

## Designer重新编译时注意

外部修改过 `.gprj` 文件列表后，已打开的Designer可能仍保留旧列表；关闭项目后重新打开本目录的 `expression_baseline.gprj`，不要用旧窗口的保存操作覆盖磁盘上的新列表。确认源文件包含 `baseline_core.v` 和 `synth_voice.v`，综合配置中的 Top Module/Entity 明确填写 `expression_baseline_top`，保存后重新运行Synthesis，再运行Place & Route。

2026-09-18实证：旧GUI列表缺少上述两个源文件，包含过时的 `expression_core.v`；TopModule为空，综合自动选择了 `expression_core`，导致PA2024报859个端口。正确工程仅有 `sys_clk/hp_bck/hp_ws/hp_din/pa_en` 五个外部端口。此错误无需改器件、CST或Dual-Purpose Pin；必须重新综合，单独重跑PnR仍会使用错误网表。证据保存在 `reports/gui_top_diagnosis/`。下方 `build.tcl` 每次明确指定顶层，可用于稳定复现。

## 试听顺序

时间从开始运行算起；循环起点包含约1秒静音。

| 开始时间 | 内容 |
|---|---|
| 1秒 | 原基准C4，持键约0.65秒后自然释放 |
| 3秒 | A4：音量全量→1/4→静音→恢复，随后完整尾音 |
| 5、6、7秒 | 同音高A4，力度1/4、1/2、全量 |
| 8秒 | 普通延音：C4/E4/G4，松键后保持，抬踏板后释放 |
| 10秒 | 选择性延音：锁住三和弦；10.4秒新A4，10.7秒松开；10.85秒释放被锁和弦 |
| 12秒 | C4/E4/G4/C5依次加入，随后全部释放 |
| 14秒 | 跨八度C大三和弦，八个声部同时保持，随后释放 |

电脑参考：`sim/baseline_preview.wav`；全段统一乘8以便试听，保留各段相对响度。`sim/baseline_raw.wav` 保留FPGA数字幅度。两者均来自RTL仿真，不是板卡录音。

## 已完成验证

- ModelSim 10.1d：声部等价/力度、混音边界、PT8211串行、完整16秒渲染四项通过。完整渲染769,232个样本、48个音符事件、17个参数命令，确认最大8声部、两种踏板行为、尾音归零。
- 开头C4与尾音：96,154个样本与原 `instrument/sim/demo_samples.txt` 完全一致。单声部独立比较累计192,308个样本通过。
- 全段数字峰值：-2602至3206码，无削波；C4频率261.631 Hz，三档力度RMS约45.21/90.47/180.99码。
- Gowin V1.9.12.03：综合、布局布线、比特流生成通过；50MHz内部setup最小余量2.543ns，hold最小余量0.125ns，违例均为0。
- 资源：4887 Logic、1088寄存器、8 BSRAM、13 DSP等效单元。仍有原 `PR1014` 普通时钟路由警告。

验证命令（工作目录为项目根目录）：

```powershell
& ./project/expression_baseline/sim/run.ps1
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/expression_baseline/build.tcl
```

受限环境中ModelSim曾报 `FileWatch(fileName)`；正常权限下上述脚本已完成运行。脚本同时检查新日志和PASS标记，不因工具返回0就记为通过。

修订版尚待用户上板试听。先核对第一声是否恢复成原认可音色，再比较力度、延音与和弦；原模拟尖锐声和底噪仍不能由RTL通过宣告修复。详细记录见 `VALIDATION.md`、`sim/audio_analysis.json` 和 `validation_manifest.json`。
