# Final Dual Timbre Candidate

这是当前终版候选，不是正式发布固件。它在独立目录中复用已经板测过的矩阵接线、EC11 针位、PT8211 发送器和八声部事件令牌，保留两种用户认可方向：`harmonic_piano` 和自然衰减 `pluck`。

## 操作映射

- 4×4 矩阵：演奏键，扫描/去抖后生成带身份令牌的按下、松开事件。
- EC11 A=`T18`、B=`R17`：默认调音量；USER_BUTTON0 短按切换到释放时间模式，再旋转调 harmonic 的释放速度。
- USER_BUTTON1：普通延音开关。pluck 保持自然衰减，不被延音强行拉长。
- USER_BUTTON2：循环切换 `harmonic_piano` / `pluck`。音色在声部启动时锁存，旧声部不会被切换动作改写。
- USER_BUTTON0 长按：全局止音，清理当前声部和输入队列。
- RGB 状态灯：音色、延音、参数模式和故障状态的可视反馈。

## 数字验证与构建

```powershell
& ./sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem'
python ./tools/build.py --gowin 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'
```

两项 testbench 已通过：`FINAL_VOICE_TB_PASS`、`FINAL_ENGINE_TB_PASS`。修正 harmonic 释放步长后的 Gowin PnR 资源为 `12723 Logic / 5459 Register / 80 BSRAM / 57 DSP / 19 IO`，50 MHz setup/hold 违例为 0。完整记录见 [resource_optimization_lab/FINAL_DUAL_TIMBRE.md](../resource_optimization_lab/FINAL_DUAL_TIMBRE.md)。

## 板测边界

用户已对本版完成下载试听，明确反馈“效果实现都比较理想”，作为音频方向第一版完整演示；矩阵、三键、旋钮与双音色功能获得认可。`impl/pnr/final_dual_timbre.fs` 为本机SRAM构建产物，未提交Git。该反馈不等于模拟噪声根因已修复，也没有新增模拟延迟、逐项灯色或音频/显示合并验收。后续[团队预算V1](../../docs/team/RESOURCE_BUDGET_V1.md)要求A先优化80块BSRAM占用；当前已验收版保留作回归基准。
