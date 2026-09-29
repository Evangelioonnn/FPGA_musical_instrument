# 验证范围与复现

日期2026-09-22；A；分支`codex/matrix-playable-v1`，起点`f9bcd79`。本轮使用Gowin V1.9.12.03、ModelSim ALTERA 10.1d、Python 3。真实板卡接线、按键手感、模拟延迟和音质留给用户验收，不能从以下数字结果推断已通过。

## 数字回归

| 测试 | 范围与结果 |
|---|---|
| buttons_tb | 独立去抖、三音色循环、音量边界、两种音色各自尾音设置、拨弦控制不适用、长按一次触发、故障清延音 |
| keys_tb | 12个事件检查；同音重弹独立32bit身份，反压载荷稳定，切换音色后正确松开旧实例；鬼键/溢出/panic/身份耗尽保护 |
| numeric_tb | 原默认与保留实现43250样本精确相同；FM默认43250样本精确相同，8档释放检查，总计247897采样点 |
| bank_tb | 5670混音帧、9次成功分配与2次拒绝；八实例容量、固定每声部增益、旧off不误伤复用槽、跨音色松键、拨弦忽略普通off |
| matrix_all_tb | 独立连通模型遍历全部65536物理按键集合；1441可唯一辨识，64095存在歧义。歧义集合中包含四角全按等同样无法排除鬼键的情况 |
| input_phase_tb | 16个键、32次转换、真实2500时钟/行与8帧去抖；短闭合被拒，数字识别延迟1.4534–1.73068ms |
| event_phase_tb | 遍历1040种采样相位，9425次原音色精确对照，覆盖相位不同的起音/松键 |
| board_tb | 真实1040时钟/音频帧，2552个PT8211串行帧、904非零帧；扫描/旋钮/板载键/三音色/鬼键/止音恢复；无采样完成丢失或重复，左右样本一致 |
| led_tb | 解码8组WS2812串行字，检查18/35时钟高电平宽度和GRB顺序、故障颜色 |

board_tb的一例输入边沿到数字串行声音为1.80703ms。这是数字仿真的单例，既不是所有音色最坏模拟延迟，也不能代替赛题要求的实测分布。板载按钮/旋钮去抖计数在board_tb中加速，独立按钮/输入测试另行覆盖功能。

三份16秒参考音由同一个render_tb乐谱驱动八槽完整RTL，每份769232样本。分音色顶层可同时运行；每个仍保留全部八槽及三种算法。只缩短采样之间的空闲系统时钟到80，音色初始化后的5帧保留1040；实际采样计算/混音/增益均运行原RTL。真实速率的串行时序另由board_tb验证。最终渲染与独立分析结果归档在[证据包](../../../evidence/matrix_playable_2026-09-22/README.md)。

原默认完整音频再由独立Python数学正弦表、十二平均律、ADSR递推、混音和音量平滑逐样本核对。事件日志记录实际声部接受的on/off；该数学核对验证音频数值，事件身份/顺序由keys_tb和bank_tb分别检查。FM的等价性按sample_valid对应的样本序号比较，允许本轮流水化多一个系统时钟。

## 构建

| 项目 | 最终结果 |
|---|---|
| 器件/顶层 | GW5AT-LV60PG484AC1/I0，Device Version B；matrix_playable_top |
| Logic | 23659 / 59904，约39.5% |
| Register | 9684 / 60780，约15.9% |
| BSRAM | 40 / 118，约33.9% |
| DSP | 97 / 118，约82.2% |
| 物理IO | 19 |
| 50MHz setup / hold | 0违例；最差余量0.251ns / 0.048ns |
| 本机bitstream | `impl/pnr/matrix_playable.fs` |
| SHA256 | `e61a0c2d746a497e2ceacb94fcd7fcbffac1980c7ab1a85b7f8c54874ffa4816` |

保留PR1014通用布线时钟警告；内部时序通过不能扩展成外部DAC、异步按钮、未连接显示器的电气时序保证。其余截位警告对应EC11/LED计数、有意定点缩位与限幅后的取位；音频路径保留数值对照，完整警告在构建记录中，没有屏蔽成“无警告”。NL0002为音量组合查表在优化中展开。

最初事件查表直连分配器造成272个setup违例、最差-1.063ns；事件增加寄存后剩15个违例、最差-1.657ns，集中在FM舍入。将等价的舍入与限幅分两级流水后收敛。失败报告保留，未用false_path隐藏问题、未降低50MHz。

## 命令

在仓库根目录执行；可用参数覆盖本机工具路径。默认run.ps1包含九项功能测试和三个渲染顶层，完整渲染耗时明显长于短回归。

```powershell
& ./project/input/matrix_playable/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' -PythonExe python
python project/input/matrix_playable/tools/analyze_audio.py
python project/input/matrix_playable/tools/build.py --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'
python project/input/matrix_playable/tools/record_evidence.py
python tools/check_repository.py
```

快速回归可指定`-Benches 'buttons_tb,keys_tb,numeric_tb,bank_tb,matrix_all_tb,input_phase_tb,event_phase_tb,board_tb,led_tb'`。分别渲染可指定`render_reference_tb`、`render_pluck_tb`、`render_fm_tb`；同时运行时给不同`-WorkLibrary`，不同时运行综合三段的render_tb与这些独立顶层，避免写同名PCM文件。

## 尚待实物确认

按[接线](WIRING.md)和[验收记录](../../../evidence/matrix_playable_2026-09-22/BOARD_REVIEW.md)操作。无二极管矩阵不能支持任意多键和弦，商品上下两幅针序图还需S1/S2/S5实测辨识。EC11按压未知；本版用底板独立按键。扬声器、压力、蓝牙、显示、本候选与SYSTEM_V0合并、完整ADSR与实时变调均不纳入本次完成结论。历史尖锐声和起音突音继续按独立音质问题定位。
