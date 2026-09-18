> 2026-09-19交接状态：16/20时钟A/B已经上板比较，用户反馈无区别；串行电气测量仍待做。 最新总状态见[STATUS](../../docs/project/STATUS.md)。下文保留原实现/验证过程；sim音频、impl比特流和manifest等本机产物不随Git提交，需重新运行脚本，精选证据见[evidence](../../evidence/README.md)。旧指纹不能当作当前文件指纹。

# 串行格式 A/B 试听

2026-09-18：同耳机播放 RTL 参考音频干净，板卡仍有尖锐声；前一版计算精度 A/B 没有改善。本工程检查 FPGA 到 PT8211 的共同串行传输方式。**用户已完成串行格式 A/B，反馈两组效果相同，尖锐声未改善；本实验不是修复。** 后续转向真实数字引脚及 DAC/模拟输出测量，见 `../audio_quality/NOISE_DIAGNOSIS.md`。

## 下载与比较

1. Gowin Programmer 保持 `GW5AT-60B` 和 **SRAM Program**，下载本工程 `impl/pnr/audio_format.fs`。本次文件名是 **audio_format.fs**，前一次是 audio_quality.fs。
2. 下载后第一组四音为 **A：原 20 时钟/声道**；第二组四音为 **B：恰好 16 个数据时钟/声道**。之后 A → B → A → B 循环，每组六秒，组间约两秒静音。
3. 使用同一耳机和原接法，试听至少两对，记录 **B 的尖锐声是否减轻、响度是否变化、有无断音或其他异常**。若第一组 A 相较旧工程已有变化，也需记录。
4. 若错过顺序，重新 SRAM 下载即可从 A 开始。既有低数字幅度没有提高；格式改变对实际模拟响度的影响仍需留意，首次先在耳边外侧确认。

原 `instrument` 和 `audio_quality` 的下载文件保留，可复核。当前无需接新外设，也无需重建工程。需要查看源码时打开 `audio_format.gprj`。

## 本次比较的内容

两个格式使用**同一个原版单声部计算模块**，音符序列、数字增益、包络和采样时刻相同。B 只在每声道开头把原四个填充时钟的时间留作低电平间隙，后16位数据时刻与 A 完全一致；采样率仍为 50 MHz/1040，不重新调整音高。

仿真确认了音频样本/WS/DIN 与原工程的一致性、格式切换边界、字长和左右解码。内部时序通过不能替代真实 DAC/模拟输出验证。即使 B 改善，也需进一步区分字捕获方式与时钟耦合，不能仅凭此认定芯片型号、手册解释或硬件损坏。

## 复现命令

在工作区根目录：

```powershell
& ./project/audio_format/sim/run.ps1
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/audio_format/build.tcl
```

脚本默认使用 ModelSim 10.1d，允许 `-ModelSimBin` 指定其他安装路径。引用 `../instrument/src` 的既有模块和约束，协作时保留目录结构。规格和报告见 `SPEC.md`、`VALIDATION.md`。
