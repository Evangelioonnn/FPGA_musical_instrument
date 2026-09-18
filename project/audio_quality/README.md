> 2026-09-19交接状态：精度A/B已经上板比较，用户反馈无明显改善；不是等待首次上板或已修复。 最新总状态见[STATUS](../../docs/project/STATUS.md)。下文保留原实现/验证过程；sim音频、impl比特流和manifest等本机产物不随Git提交，需重新运行脚本，精选证据见[evidence](../../evidence/README.md)。旧指纹不能当作当前文件指纹。

# 正弦音质 A/B 试听

这是针对 M1 尖锐附加声的独立诊断工程。RTL 仿真、数字频谱比较和 Gowin 综合/PnR/内部时序已通过；**2026-09-18 用户反馈 A/B 听感相同，尖锐声未改善，问题未修复。** 原 `project/instrument` 的 RTL 和下载文件保留。最新分析与下一步见 `NOISE_DIAGNOSIS.md`。

## 下载与听法

1. 保持目前的耳机、接线和供电方式，以便比较。
2. Gowin Programmer 保持 `GW5AT-60B`，选择 **SRAM Program**，下载本目录的 `impl/pnr/audio_quality.fs`。不需要新外设。
3. 从下载完成开始，约 1 秒后第一组四音为 **A（原计算方式）**；第二组同样的四音为 **B（插值与舍入）**。之后按 **A → B → A → B** 循环。每组为 C4、E4、G4、C5；相邻两组之间约有 2 秒静音。
4. 两组保持相同音高、ADSR 和名义音量。连续听至少两对，重点判断 B 的尖锐附加声是明显减轻、基本不变还是更明显；同时记录静音底噪和是否有新异常。若错过顺序，可重新 SRAM 下载，从第一组 A 开始辨认。

不需要重新编译即可使用已生成的 `.fs`。若需要打开工程，选择 `audio_quality.gprj`。

## 改了什么

A 保留原 1024 点正弦表及截断；B 对相邻表值作 8 位小数线性插值，并对最终幅度舍入。两路在 FPGA 内实时计算，只选择一路送给同一个 PT8211 输出模块，不进行叠加。

数字仿真的四音保持段中，B 最强的 2～20 kHz 残差谱线比 A 低约 9～17 dB，基波幅度差约 0.0015 dB；总残差约改善 3.6 dB。**这些结果仅针对仿真数据，不能证明耳机中的尖锐声源自数字计算，也不能证明模拟底噪有所降低。** 详细测量见 `VALIDATION.md`。

## 复现

在工作区根目录运行：

```powershell
& ./project/audio_quality/sim/run.ps1 -PythonExe python
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/audio_quality/build.tcl
```

仿真使用现有 ModelSim 10.1d，`-ModelSimBin` 可指定安装目录；频谱分析需要 numpy。其他电脑可把 `-PythonExe` 改为已安装 numpy 的 Python。工程引用 `../instrument/src` 的既有模块和约束，协作时需要保留目录结构。

本工程的 3 BSRAM、3 DSP 包含同时运行的 A/B 通路，是诊断版本占用，不能作为最终单声部资源数据。
