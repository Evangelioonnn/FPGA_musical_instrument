> 2026-09-19交接状态：用户已上板确认左右均衡、无断音和明显杂音；这是低幅方波基础发声，不是正弦音质验收。 最新总状态见[STATUS](../../docs/project/STATUS.md)。下文保留原实现/验证过程；sim音频、impl比特流和manifest等本机产物不随Git提交，需重新运行脚本，精选证据见[evidence](../../evidence/README.md)。旧指纹不能当作当前文件指纹。

# 音频探测验证记录

日期：2026-09-17。状态：**软件验证、比特流生成和耳机上板试听均完成。**

## 修改原因

初稿从第三方驱动推导的数据窗口不符合 PT8211 手册右对齐图示；旧测试又假定所有帧保持同一个正值，无法正确验证 DDS。已按芯片手册重定规格：WS 低=右、高=左，每个声道 4 个前导零 + 16 位数据，最后一个数据位紧挨 WS 翻转。样本幅度从正负 12000 降到正负 512。原 LED 工程未改。

旧的 `tmp/audio_probe_tb.v` 测试已退役；有效测试只在本工程 `sim` 中。

## RTL 仿真

命令（工作目录为仓库根目录）：

```powershell
& ./project/audio_probe/sim/run.ps1
```

- ModelSim ALTERA Starter Edition 10.1d，普通 Verilog 模块。
- 模拟时间 25 ms，每个实例完成 1201 帧。
- 独立接收器在 WS 翻转时锁存最近 16 位；不读取 DUT 的计数器/相位来生成期望值。
- 完整 DDS 输出逐帧与频率公式对照；另一个实例注入不同左右样本，验证 MSB/LSB、符号、声道与帧边界。
- 检查 BCK 半周期 260 ns、每声道 20 BCK、4 个前导零、DIN/WS 只在 BCK 低时改变、上升沿前稳定时间至少 260 ns、PA_EN=0 和无未知值。
- 日志 `sim/simulation.log`：`TONE_CHECK_PASS frames=1201 measured_hz=440.175288`、`PATTERN_CHECK_PASS frames=1201`、`AUDIO_PROBE_TB_PASS`。
- 测得频率与精确设计值约 440 Hz 的差异来自有限样本窗口。实际晶振误差未测。
- ModelSim 曾在受限执行环境中出现 `FileWatch(fileName)` / 日志权限错误，授权在沙箱外运行后通过。进程返回 0 不足以证明仿真成功，脚本检查所有通过标志和错误文本。

## 综合、布局布线与时序

```powershell
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/audio_probe/build.tcl
```

- Gowin V1.9.12.03，GW5AT-LV60PG484AC1/I0 / Version B。
- 综合、PnR、比特流生成完成；引脚和 Bank 3.3 V 与工程 CST 一致。
- 59 个逻辑单元（24 LUT + 35 ALU），46 个寄存器（44 逻辑 FF + 2 IO FF），5 个端口，无锁存器。
- 20 ns 系统时钟约束下，最差 setup slack **+14.131 ns**，hold slack **+0.250 ns**；违例端点均为 0，TNS 均为 0。
- 综合网表核对到 BCK/WS/DIN、位计数器、分频计数器和相位寄存器的 INIT；无需依赖仿真器自动清零。
- 唯一 PnR 警告 `PR1014` 与 LED 基线相同；V22 输入用普通路由进入 PRIMARY 时钟网络。保留警告与原约束，后续扩展设计需重新评估。
- 输出：`impl/pnr/audio_probe.fs`，生成时间 2026-09-17 00:37:23，17,311,931 字节。

## 限制和下一步

- SDC 目前仅定义系统时钟；上述 STA 结论覆盖内部同步路径，**不代表 DAC 端输出时序、板级信号完整性已验收**。
- 本次未运行 Gowin 原语/后布局仿真，也未实际测量板上 BCK/WS/DIN。
- 2026-09-17 用户完成耳机 SRAM 下载实测：左右声道均有声音，音量均衡，无断音和杂音；未接外接扬声器，未改写 Flash。
- 这次试听验收了音频链路的基本功能和听感稳定性；没有仪器测量 BCK/WS/DIN 波形、频率误差、失真或输出声压。
- 通过后再加入按键控制、包络和更完整的音频接口约束，不把本工程直接视为比赛成品。
