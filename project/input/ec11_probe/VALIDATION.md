# EC11独立探针验证 · 2026-09-19

角色A；任务分支`feat/ec11-board-probe`，基于`d96ef7f`。新增本工程及板卡/状态记录，原`ec11_input`和`instrument`源码未改；依赖现有工作区基线。此次未远端push，未代操作板卡。

## 可重复命令

仓库根目录执行：

```powershell
& ./project/input/ec11_probe/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/input/ec11_probe/build.tcl
```

## 数字仿真

ModelSim ALTERA 10.1d，纯RTL。使用真实50MHz与默认50μs采样周期/100μs AB稳定窗口，非缩短参数冒充硬件时序。先在沙箱内遇到历史已知的`FileWatch(fileName)`启动错误，正常权限重跑通过；脚本检查错误和新PASS标志，不能只看退出码。

- `EC11_PROBE_TB_PASS events=83 up=41 down=42 note=69 frames=9717`，仿真202.120ms。
- 独立Gray输入刺激检查正反、20μs毛刺、稳定往返抖动、双位非法跳变后的恢复、静止不触发、48/84音号饱和不回绕。
- 用独立十二平均律公式检查真实DDS的频率增量；不只验证音号元数据。
- 从顶层BCK/WS/DIN重新解码最后16位PCM，检查20时钟/声道、260ns BCK半周期、低沿改数据、双声道相等、电平在原-512..511范围。
- 解码后的PCM零交叉频率：A4目标440Hz、测得440.063369Hz；A#4目标466.163762Hz、测得466.070097Hz；返回A4为440.063369Hz。有限观测窗和样本量化造成测量差异，均在0.5%判据内。

## 综合、PnR

Gowin V1.9.12.03，GW5AT-LV60PG484AC1/I0、Version B，顶层`ec11_audio_probe_top`。Logic 578，Register 148，BSRAM 1，DSP 1，IO 7。50MHz约束下setup/hold违例端点均0，TNS均0。

输入为Bank6的T18/R17、LVCMOS33、内部上拉；音频/时钟继续沿用V22/Y17/AB17/AA16/AB16。异步A/B只进入第一级同步寄存器，SDC豁免端口至首级同步路径，同步级之间仍做时序检查。未给外部DAC添加虚构的输出延迟，外部实际时序待测。

保留的告警：共享解码器`EX3791`为6位`next_partial`存入5位`partial`；当前4相位阈值下仅在-3..3时保存，适合该位宽。`PR1014`为已知V22时钟路由告警。首次CLI还提示不能写AppData下`sh.log`，但本工程综合/PnR日志、报告、bitstream均完整生成；未把这个缓存日志提示当作硬件错误。

本次生成`impl/pnr/ec11_probe.fs`，SHA256：

```text
B1A54E82466FF82869C325CDCFB603EC21BE04D6B90BE64D8157968C3CEBDAA3
```

该哈希对应本次构建，不要求不同版本工具重建逐字节一致。

## 实物验收 · 用户板测

用户按本次构建的 SRAM 下载指引，用耳机完成验收。接线条件为：模块 VCC→PMOD 3.3V，模块 GND→PMOD GND，A→T18，B→R17，C悬空；用户未另外报告下载截图、供电组合或测试时长。结果如下：

- 连续旋转时音高变化不卡顿；快转和慢转均未听到异常。
- 顺、逆两个方向均能正确改变音高。
- 每个机械卡点恰好触发一次音高变化。
- 停止旋转后音高保持稳定，没有自行跳变。

这证明本模块在当前3.3V供电和A/B接法下已完成真实数字输入、解码、DDS变调和耳机输出功能验收。`EC11_STEPS_PER_DETENT=4`与用户实物的每格相位关系匹配，暂不调整；尚未采集A/B波形。顺时针具体对应升音还是降音未报告；若整机希望改变方向，交换A/B语义即可。

C脚仍保持悬空。此前断电电阻测量为C–VCC约9.9kΩ、C–GND超量程、按压不变，因此没有把C当作直接地或已确认按键输入；旋转验收不依赖C。板卡原耳机尖锐噪声依然未解决，本轮只证明EC11输入链路有效，不改变音质结论。
