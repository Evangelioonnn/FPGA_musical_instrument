# 音频核心 V1 证据范围

2026-09-28，角色A，任务分支 `codex/audio-core-v1`，源码起点 `de84fd3`。
本目录记录新的五音色参数/效果整合、独立16/32声部钢琴结果，**没有新增实物验收**。

完整说明和复现命令见[主工程VALIDATION](../../project/audio_core_v1/VALIDATION.md)，
用户入口见[验收指南](../../docs/project/AUDIO_CORE_REVIEW_2026-09-28.md)。
`validation.json`由主工程收集脚本核对当前源/.fs/WAV指纹、成功日志和资源门槛后生成。
已完成仿真日志的当前依赖时间也被核对；不把当前源哈希伪装成构建前自动记录的历史仿真哈希。
构建源哈希确实在Gowin运行前后比对，变动即拒绝该输出。

| 构建范围 | Logic | Register | BSRAM | DSP | setup余量 |
|---|---:|---:|---:|---:|---:|
| 五音色八声部+现有输入+房间效果 | 24151 | 10918 | 42 | 72.5 | 2.562ns |
| 独立钢琴16安全版 | 4571 | 3627 | 4 | 2 | 1.832ns |
| 独立钢琴32安全版 | 6048 | 3341 | 10 | 2 | 3.146ns |

三份19IO板级工程50MHz setup/hold均0违例，构建输出本机保存，不提交Git。
完整逻辑接口另做仅综合审计，不能当整机PnR：24180 Logic/11907 Register/39 BSRAM、DSP估算72.5。
钢琴16/32固定每音减半/四分之一，独立每声部相位/频率/包络；不是4谐波冒充32振荡器。
五音色与32声部尚未共同切换或整合，显示/蓝牙尚未接入。

[32不同基频补证据](../../project/audio_polyphony_lab/SPECTRUM.md)已在32768帧实际RTL PCM中
检出全部目标谱峰，并核对32个不同token/频率步进/非零包络。FFT存在跨声部谐波重合，
独立性结论须同时核对状态和独立模型，不能把数字频谱当作板卡模拟测量。

独立结果：[参数服务](../../project/audio_parameter_lab/VALIDATION.md)、
[高复音](../../project/audio_polyphony_lab/VALIDATION.md)、
[短房间/颤音](../../project/audio_fx_lab/VALIDATION.md)。
主PCM参考见 `evidence/audio/audio_core_v1_2026-09-28.wav`，高复音参考同目录piano8/16/32。
WAV来自实际RTL输出，没有响度归一化，不是模拟录音或FPGA回放素材。
主预览的仿真正弦ROM用全地址/未知地址等价的同步数组加速，950帧原ROM整链对照相同；
固件仍用原综合RTL。验证JSON保留该模型的生成来源、比较结果及源指纹。
每段PASS帧数与PCM行数逐一绑定，六段PCM指纹及拼接后的WAV数据均被核对；
手动补跑缺失场景后可用 `project/audio_core_v1/tools/assemble_preview.py` 校验并重新组装。
六个试听场景分别复位、分别检查后拼接，首场景对照原连续渲染；不据此宣称连续切换听感通过。

未验证：真实新固件听感、实体SPI ADC与推子/25键PCB、音频到模拟输出延迟、
尖锐伴音根因、HDMI/蓝牙CDC和合并后的资源/时序。
旧final_dual_timbre、custom_harmonic_lab等记录保持原范围。
