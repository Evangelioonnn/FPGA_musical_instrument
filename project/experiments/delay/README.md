# 短反馈延迟实验

`feedback_delay.v` 是独立的采样率反馈延迟候选：默认 4096 个样本，约 85.2 ms（实际 Fs=50 MHz/1040=48076.923 Hz），反馈 0.75、湿声 0.5。默认系统没有接入它，原正弦＋ADSR试听路径保持不变。

设计约束：存储器不在复位时清零，由 `fill_count` 屏蔽复位后的历史；反馈乘法按 Q15 截断到零，避免负值产生 -1 极限环。湿声系数每接受一个样本向目标走256，默认64个样本约1.33ms完成开/关；旁路过渡完成后逐样本精确干声，延迟线仍运行，重新开启可以听到已有尾音。输出饱和和 `clipped` 均单独可测。它只接受数字音频样本，尚未代表板卡模拟噪声已解决。

握手：in_valid && in_ready在上升沿接受；下一上升沿输出out_valid/out_sample。最小接受间隔2个系统周期；实际音频为1040周期。延迟参数满足1≤DELAY≤DEPTH；反馈Q15取0..24576，湿声0..32768。本次数值覆盖8和4096采样延迟。不要仅改参数成不稳定反馈。

## 验证

```powershell
./project/experiments/delay/sim/run.ps1 -ModelSimBin E:/QuartusII/modelsim_ase/win32aloem -PythonExe python
```

Python独立历史序列oracle覆盖384068个样本：正负脉冲、反馈衰减、随机满幅、饱和、复位、湿声渐变、旁路恢复。另把16秒默认演示经RTL延迟并增加尾音，865232样本通过独立数值复核，试听见[delay_preview.wav](../../../evidence/audio/delay_preview.wav)，固定×4试听增益。

`delay.gprj`的Top是`delay_top`，仅为1个原voice＋固定延迟＋PT8211资源/时序探针，不是演奏系统；动态bypass端口在这个顶层接常量0，综合会裁剪旁路分支。真正接入整机前重新检查资源、时序、可切换旁路和板级听感。
