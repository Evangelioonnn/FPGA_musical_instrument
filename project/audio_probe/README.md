> 2026-09-19交接状态：用户已上板确认左右均衡、无断音和明显杂音；这是低幅方波基础发声，不是正弦音质验收。 最新总状态见[STATUS](../../docs/project/STATUS.md)。下文保留原实现/验证过程；sim音频、impl比特流和manifest等本机产物不随Git提交，需重新运行脚本，精选证据见[evidence](../../evidence/README.md)。旧指纹不能当作当前文件指纹。

# Tang Mega 60K 耳机音频探测

独立验证工程，原点灯工程 `../test` 保留。目标是验证 FPGA 到板载 DAC、功放、3.5 mm 耳机口的链路，不是比赛合成器的完整实现。

## 规格与依据

- 器件：GW5AT-LV60PG484AC1/I0，Device Version B。
- 唯一内部时钟：V22 上的 50 MHz；声明初值用于 FPGA 配置后的初始化，无外部复位端口。
- 输出：BCK Y17、WS AB17、DIN AA16、PA_EN AB16，均为 3.3 V。来自官方 `tang_mega_60K_pins.cst`。
- 底板依据：`Notification/Mega60K_官方资料/板卡原理图/Tang_Mega_NEO_Dock-60K_31004_Schematics.pdf` 第 10 页。PT8211-S → LMV321 低通滤波 → NS4263 → 耳机/扬声器。PA_EN=0 开启功放；耳机检测切换由底板完成。
- 串行格式依据：PTC PT8211 V1.6 第 4 页 Figures 1/2，已保存为 `Notification/Mega60K_官方资料/部分芯片手册/PT8211_V1.6.pdf`。来源 https://www.pjrc.com/store/pt8211.pdf （厂商手册的镜像）。
- PT8211 为 **LSBJ 右对齐**，不是标准 Philips I2S。DIN 在 BCK 上升沿采样，MSB 先发，16 位二补码；WS=0 右声道、WS=1 左声道；LSB 采样后的下降沿翻转 WS。
- 本工程选择每声道 20 BCK：4 个前导零，再 16 位数据，无尾随填充。20 不是芯片规定的唯一长度。
- BCK=50 MHz/26≈1.923077 MHz；一帧 40 BCK，采样率≈48076.923 Hz。数据和 WS 在 BCK 下降沿更新，留 260 ns 到下一采样上升沿。
- DDS 每帧更新一次，32 位相位增量 `0x0257C915`，约 440 Hz；左右声道相同，正负 512 的方波，约 -36 dBFS。较小数字幅度不等于已测得耳机声压。
- 帧内样本不变；左右声道使用同一帧样本。仅系统时钟驱动寄存器，不把 BCK 用作内部时钟。

## 验证

`sim/audio_probe_tb.v` 独立地在 WS 边界锁存最近 16 个 DIN 位，检查完整样本、声道顺序、位时钟周期、20 BCK/声道、数据相对采样边沿的稳定时间和约 440 Hz 频率；另用正负非对称测试样本检验声道和位序。

`sim/run.ps1` 使用本机已有 ModelSim 10.1d；只验证纯 RTL，不代表 Gowin 原语或后布局仿真通过。

`build.tcl` 使用本机 Gowin 的 `gw_sh.exe` 运行综合与布局布线。时序结果及已知限制见 `VALIDATION.md`。

## 上板

1. 断开 USB 和 DC 电源后，插入 3.5 mm 有线耳机。耳机先不戴到耳朵上，不接扬声器。
2. 恢复供电，DEBUG-USB2 连接电脑。
3. Gowin Programmer 使用 GW5AT-60B，选择 **SRAM Program**，文件为本工程生成的 `impl/pnr/audio_probe.fs`，保留出厂 Flash。
4. 下载后耳机应有持续音调；先在耳边外侧确认音量。已实测结果：左右声道均有声音、音量均衡、无断音和杂音。

听到声音由用户实测后才能验收。电脑音量滑块不能控制 FPGA 直接输出的音量。断电会丢失 SRAM 配置，重新上电可能恢复出厂演示。
