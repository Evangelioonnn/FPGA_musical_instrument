# 集成候选 v0

本任务在 `feat/playable-system-v0`，起点 `4ada74e`；A负责，范围是音频整合、输入适配、共享接口候选及验证。默认声音复用原instrument，原工程源码没有改动。先看[早上验收指南](../../docs/project/MORNING_REVIEW.md)、[规格](SPEC.md)和[当前状态](../../docs/project/STATUS.md)。

## 两种不同的入口

| 入口 | 实际做什么 |
|---|---|
| `system.gprj` / `system_top` | 只有5个已知时钟/音频IO，自动播放旧16秒演示；不读取外部矩阵、EC11或压力 |
| `control_surface` → `system_engine` | 可复用的逻辑输入链路，已经端到端仿真；还缺实际行列/编码器针位、ADC适配与整机CST |

`system_engine` 包含事件FIFO、两个配置来源仲裁、真实电平快照及波形抽取。N=8/16/32；32声部额外一级事件寄存，采样率不变。板级演示的观测端口没有连接消费者，综合会裁剪这些逻辑；其资源不能代表最终带显示/输入整机。

## 复现

在仓库根目录运行（工具路径按本机设置）：

```powershell
./project/system/sim/run.ps1 -ModelSimBin E:/QuartusII/modelsim_ase/win32aloem -PythonExe python
./project/experiments/delay/sim/run.ps1 -PythonExe python
python project/system/tools/export_audio.py
& 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe' project/system/build.tcl
```

完整数字测试约需数分钟；`-Benches keys_tb,matrix_tb`可选择局部测试。完整音频渲染压缩了两次采样之间空闲时钟，声音的采样数/包络不缩短；真实50MHz/1040串行与输入延迟由单独测试验证。NumPy用于音频分析，向量生成只需Python标准库。不要同时运行两个使用本目录ModelSim库的任务。

`build.tcl`明确设置顶层。GUI打开后仍应确认Top为`system_top`，不能用`system_core`或`input_audit_top`做板级顶层。板级CST引用原instrument的5个已核验IO。

## 已验证的关键行为

- 769232个默认演示样本与旧baseline精确相等，包括原音色、电平、包络和演示节奏。
- 按键持有时改变映射，松键仍释放原音；同音物理键合并所有权。无二极管鬼键触发全释放，全部实体键松开后再武装。
- 配置只接受音量、普通延音、选择性延音、全释放；不支持的音色/ADSR配置明确拒绝。
- 修复旧baseline的重定音缺口：新`system_voice`将pitch_we送到真实DDS；用相位增量验证，不只检查状态标签。
- 真实meter、快照序号、波形索引和独立CDC辅助模块有数值/一致性测试。C仍需接显示像素域及实现时序约束。

证据见[evidence](../../evidence/system_v0_2026-09-19/README.md)。**没有新增真实板测；耳机尖锐声仍未解决。** 本版本尚未实现动态ADSR、多音色选择、滑音/弯音界面、BLE协议、显示输出、逐键压力、同音独立source身份。
