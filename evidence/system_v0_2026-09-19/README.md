# system v0夜间验证

分支`feat/playable-system-v0`，起点`4ada74edd085fd3adeb5a4272704de9fd1035f65`。源码/文档/测试随本次提交，构建工具Gowin V1.9.12.03、仿真ModelSim ALTERA 10.1d。**未新增板测，真实耳机尖锐声未解决。**

已从暂存区全新导出并独立重跑关键仿真及system完整构建，见[干净目录复现](CLEAN_REPRODUCIBILITY.md)。

## 复现命令

从仓库根目录，Python路径可替换为本机版本；NumPy用于音频分析：

```powershell
./project/system/sim/run.ps1 -ModelSimBin E:/QuartusII/modelsim_ase/win32aloem -PythonExe python
./project/experiments/delay/sim/run.ps1 -ModelSimBin E:/QuartusII/modelsim_ase/win32aloem -PythonExe python
python project/system/tools/export_audio.py
python project/experiments/timbre/render_candidates.py

# 其余build.tcl路径见builds.json和各工程README；32声部会完成构建但时序失败。
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/system/build.tcl
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/input/build_audit.tcl
python project/system/tools/record_builds.py
python tools/check_repository.py
```

归档脚本要求全部测试日志和各工程构建已经存在；不会替你省略缺失/失败测试。本目录的.fs哈希只标识A本机当时的实际输出，新克隆重新构建需记录自己的哈希。源文件哈希是本机构建输入字节（可能受换行影响）；语义复现以相同源码与测试/实现结果为准。

## 数字测试结果

| 验证 | 结果 |
|---|---|
| FIFO/仲裁 | 7456次FIFO检查，6033次满队列同进同出、10044次等待；两配置源1481/1480接受，等待载荷保持 |
| 按键路由 | Python独立所有权模型，2006份状态、3808条事件，含同音、持键改映射、随机反压 |
| 矩阵/编码器 | 236组布局/电气连通测试，鬼键与二极管多键；EC11正10/反7格、非法跳变2次、按钮边沿2次 |
| 压力/配置 | 1200数值向量、校准与超时恢复；配置10000向量，661接受、6377拒绝 |
| 溢出保护 | 满队列/鬼键后释放，实体全松才恢复，没有遗留旧事件；综合查出的ready反馈环已修正 |
| meter/抽取/CDC | 18960样本、18个电平窗口、395个波形点；1228份跨域payload一致送达，6290份繁忙时明确丢弃 |
| 默认音色回归 | 16秒769232样本逐点等于原baseline，751状态快照、16026抽取点 |
| 输入到PT8211 | 真50MHz/1040：3次on、2次off、1942帧，事件识别1.600370ms、首个非零解码字1.794392ms；这是一个受测相位/场景，不是所有条件的最坏延迟证明 |
| 默认串行 | 2048帧、48音符事件、10个支持配置，20BCK/声道、电平变化边沿均检查 |
| 16/32核心 | 分别34015/34025样本，全部声部独立、真实相位retune、抢占、延音、panic释放归零 |
| 32串行 | 2048帧、32个独立on，寄存后的事件顺序无变化；RTL通过不抵消PnR失败 |
| 输入试听/长音 | 输入链6秒288462样本，6on/6off；C4/A4各10秒480770样本，静音与保守电平验证 |
| 短延迟 | 独立Python历史模型，8/4096延迟共384068样本；正负衰减、2011次输出削波、复位、旁路渐变；865232个渲染样本另逐点复核 |

完整PASS行及源/固件指纹见[builds.json](builds.json)，频率/各声部谱峰/音频SHA见[audio_analysis.json](audio_analysis.json)。单元测试长渲染压缩系统空闲周期，`system_input_tb/transport_v0_tb/capacity_transport_tb`使用真实1040周期。所有频谱/音频来自数字仿真。

## 独立顶层资源与50MHz内部时序

| 顶层 | Logic | 寄存器 | BSRAM /118 | DSP /118 | setup / hold (ns) | 结果 |
|---|---:|---:|---:|---:|---|---|
| system_top (8声部) | 5008 | 1284 | 8 | 13 | +1.320 / +0.143 | 通过 |
| capacity16_top | 10049 | 2139 | 16 | 25 | +2.078 / +0.127 | 通过 |
| capacity32_top | 25349 | 4069 | 32 | 49 | **−5.458** / +0.134 | **230个setup违规端点** |
| delay_top（单原voice＋效果） | 454 | 181 | 5 | 3 | +3.914 / +0.046 | 通过 |
| lab_top C4 | 286 | 116 | 1 | 1 | +13.290 / +0.121 | 通过 |
| lab_a4_top | 288 | 118 | 1 | 1 | +12.788 / +0.143 | 通过 |
| lab_silent_top | 117 | 60 | 1 | 1 | +13.619 / +0.187 | 通过 |

输入逻辑`input_audit_top`仅综合：1198 Logic、583寄存器、4 BSRAM，无DSP；316个逻辑端口没有物理约束，**不能下载**，报告中默认100MHz综合估计不作为实际时序承诺。

system/capacity顶层未连接显示消费者，meter/tap/部分配置逻辑被裁剪；delay_top把bypass固定0，部分控制被裁剪。资源不是完整的输入＋音频＋显示整机预算，也不能将独立数相加当最终实现。通过项的SDC只声明50MHz内部时钟，未对外部PT8211电气setup/hold作完整板级约束；外部链路仍需实测。

全部板级构建仍有PR1014（V22时钟路径使用通用布线）警告。capacity顶层有受范围限制的位宽截断警告；输入EC11累计器及效果中间结果也有已知有界截断，数值测试覆盖实际默认范围。NL0002按已披露的常量/无消费者裁剪，不是“完整模块零资源”。

32声部增加事件寄存前setup为−5.188ns，之后−5.458ns，Fmax约39.280MHz。失败报告保留，下一步要流水化或顺序化声部分配逻辑。不得通过忽略时序报告把本轮32声部写为正式指标达成。

## 可追溯发现

- 旧baseline retune只改音高标签，没有触达DDS；新system修复并检查实际phase增量，旧参考RTL保留。
- 输入快照的overflow若依赖包含fault门控的ready，会形成组合反馈环；改为寄存占用量判定后Gowin环路警告消失，相关仿真重跑。
- 反馈延迟使用同步RAM读取，最终映射到4块SDPB（加原voice ROM共5块BSRAM）；负反馈缩放向零截断以避免负一代码驻留。

早上操作顺序见[验收指南](../../docs/project/MORNING_REVIEW.md)。
