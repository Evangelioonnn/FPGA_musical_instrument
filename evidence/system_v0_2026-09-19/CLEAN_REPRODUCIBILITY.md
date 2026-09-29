# 干净导出复现 · 2026-09-19

从Git暂存区用checkout-index导出350个发布文件到全新目录；没有复制原工作区的ModelSim库、仿真样本、impl、Notification或本机未跟踪数据。先运行tools/check_repository.py，通过链接、gprj/include依赖与参考原文件SHA检查。

## 实际重跑范围

- 编译全部新旧依赖RTL；独立生成按键/压力/配置向量。
- keys_tb、system_input_tb、完整16秒equivalence_tb。
- 延迟8/4096数值测试、完整原曲目的延迟渲染。
- system_top完整Gowin综合、PnR与bitstream。setup/hold违规端点均为0，保留PR1014；不代表新增板测。

- `KEYS_TB_PASS snapshots=2006 events=3808`
- `SYSTEM_INPUT_TB_PASS on=3 off=2 frames=1942 control_to_event_ns=1600370 control_to_serial_ns=1794392 snapshots=1 ghost_release=1`
- `EQUIVALENCE_TB_PASS samples=769232 snapshots=751 wave_samples=16026`
- `FEEDBACK_DELAY_TB_PASS D=8 samples=6030 clips=437 resets=2 oracle=python_history`
- `FEEDBACK_DELAY_TB_PASS D=4096 samples=378038 clips=1574 resets=2 oracle=python_history`
- `DELAY_RENDER_TB_PASS samples=865232`

导出版本的system_samples.txt和delay_samples.txt与工作区验证数据逐字节相等。独立重建system.fs SHA256：`41cb884fc3958a6985368fcbf081cf95005d729b7acf1e5087e08c42caf0af7a`。它是复现构建的指纹，板测仍应记录实际下载文件的SHA。

此次仅在干净目录重建system，没有在该目录重复所有lab/capacity工程；这些工程的验证范围见builds.json。最终文档补记没有改变上述受测源码。
