# Gowin打开、构建与SRAM下载

请完整克隆仓库并切换交付分支 `codex/c-waveform-page`，进入 `project/visual/instrument_ui_redesign/`。无需旧UI/旧波形文件夹；必要共享源码通过相对路径引用。音频基线、当前硬件限制见HANDOFF_ZH.md。

## Gowin Designer

1. File → Open → `instrument_ui_redesign.gprj`。
2. 核对器件GW5AT-LV60PG484AC1/I0，GW5AT-60B、Version B、PBG484A。
3. Configuration中设置Top Module=`instrument_ui_top`，Output Base Name=`instrument_ui_redesign`。
4. Run All，或依次Synthesize、Place & Route。也可在Gowin Tcl控制台执行 `source {你的完整仓库路径/project/visual/instrument_ui_redesign/build.tcl}`，脚本自动设置顶层和输出名。
5. 完成后在本目录执行 `python check_build.py`，必须满足download_gate_pass=true、50/150MHz时序通过、setup/hold违例0及针位检查。工具会记录实际资源与SHA；不同源码或构建的结果不得沿用。

## Programmer

1. 保持板卡USB数据线、耳机、显示器HDMI和电源连接；Tools → Programmer。
2. USB Cable Setting选择检测到的USB Debugger A端口，核对器件GW5AT-60B。
3. Operation仅选 **SRAM Program**，FS File为本次构建的 `impl/pnr/instrument_ui_redesign.fs`。
4. 点绿色运行箭头，确认Finished且无错误。长按USER2约0.8s进入波形页，应显示SCOPE AUTO V2。
5. 依BOARD_TEST_ZH.md检查。PEAK为原始数字码；AUTO x2^ n为显示倍率。静音应回零，干声L/R相同正常。

源码仓库不包含.fs、impl或仿真工作库。每位队友本地构建；编译前核对 `python tools/verify_delivery.py`，源码与交付的实际PnR指纹应一致。PowerShell用 `Get-FileHash -Algorithm SHA256 .\impl\pnr\instrument_ui_redesign.fs` 与本机构建报告核对。SRAM下载掉电失效；本流程不改Flash。

## RTL复现

`powershell -ExecutionPolicy Bypass -File .\sim\run_v2.ps1 -VivadoBin '你的Vivado/bin目录'`

`powershell -ExecutionPolicy Bypass -File .\sim\run_wave.ps1 -VivadoBin '你的Vivado/bin目录'`

两脚本共六项测试，完成后运行 `python tools/record_delivery.py` 生成本机验证记录，再执行 `python tools/verify_delivery.py --require-sim`。不需要下载字体或旧项目来运行。编译自带字模不依赖Pillow；仅离线修改文字时才运行generate_ui_roms.py。

## 本工程实际针位


| 信号 | 针位 | 电气 |
|---|---|---|
| 50 MHz sys_clk | V22 | LVCMOS33 / 3.3 V |
| EC11 A / B | T18 / R17 | LVCMOS33 / 3.3 V |
| USER_BUTTON0 / 1 / 2 | AA13 / AB13 / Y12 | LVCMOS15 / 1.5 V |
| matrix_col_n[0..3] | AB22、AB21、Y22、Y21 | LVCMOS33 / 3.3 V |
| matrix_row_n[0..3] | AA20、AA21、AA19、AB20 | LVCMOS33 / 3.3 V |
| hp_bck / hp_ws / hp_din / pa_en | Y17 / AB17 / AA16 / AB16 | LVCMOS33 / 3.3 V |
| TMDS data0 P / N | J14 / H14 | LVDS25E / 2.5 V |
| TMDS data1 P / N | J15 / H15 | LVDS25E / 2.5 V |
| TMDS data2 P / N | K17 / J17 | LVDS25E / 2.5 V |
| TMDS clock P / N | G15 / G16 | LVDS25E / 2.5 V |

集成工程的 Y12 是 USER_BUTTON2 音色键，**不是彩条探针的 rstn**。采用内部上电复位；EC11 按压未接入。J16 状态灯未输出，避免与视频 Bank 电压冲突。实际 IO 总数 26。

共享 PLL 配置和串行器来自已验证链路，GPRJ 已列出必要源文件；时钟分别为 50/150/750 MHz。CST/SDC 只使用本目录版本，不覆盖旧音频工程约束。
