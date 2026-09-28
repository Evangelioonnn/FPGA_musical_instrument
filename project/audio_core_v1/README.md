# 音频核心 V1 · 五音色可演奏候选

2026-09-28，A负责，分支 `codex/audio-core-v1`，源码起点 `de84fd3`。
本轮在独立目录完成音频与现有输入的整合，没有修改已板测的旧工程。
9月29日用户已认可本目录主工程音色/效果及独立16/32复音，见[实物反馈](../../evidence/audio_core_v1_2026-09-29/BOARD_LISTENING.md)。
这是本轮音频方向回退，后续32/12五音色整合候选在audio_core_v2，仍需单独板测；模拟SNR/延迟及实体ADC/C整机未验证。

## 交付内容

- 五音色按固定ID `0→2→3→4→5→0` 切换：Precision harmonic piano、Warm pluck、Metallic bell、Drive lead、自定义四谐波。ID1原拨弦保留在历史源码，不进入新菜单。
- 八声部逐次击键身份、双区八度、普通/选择性延音，以及适合Lead的滑音、弯音和可关闭颤音。Warm pluck保持自然衰减。
- 一份参数服务统一板载键/EC11、未来主机配置和模拟ADC扫描；包含接管、非法值拒绝、主音量平滑与四谐波限幅。
- 可关闭的短房间立体声效果器、完整ADSR覆盖、真实PCM/声部状态/电平快照。效果与ADSR覆盖默认关闭。
- 钢琴16/32声部在[独立实验](../audio_polyphony_lab/README.md)验证，不声称五音色已全部扩到32声部。

阅读[上板验收](BOARD_TEST.md)、[规格](SPEC.md)、[数字及实现结果](VALIDATION.md)。
B/C的适配入口是[音频接口V1](../../docs/interfaces/AUDIO_CORE_V1.md)，不是复制旧SYSTEM_V0的位布局。

## 复现

在仓库根目录运行，脚本可用 `--modelsim` / `--gowin` 指定工具位置：

```powershell
python project/audio_core_v1/sim/run.py
python project/audio_parameter_lab/sim/run_parameters.py
python project/audio_core_v1/tools/build.py
python project/audio_core_v1/tools/render.py --fast-rom --jobs 3
# Optional: verify and reassemble six complete scene outputs after manual reruns.
python project/audio_core_v1/tools/assemble_preview.py
python project/audio_core_v1/tools/record_validation.py
python tools/check_audio_evidence.py
```

Designer入口为 `audio_core.gprj`，**Top Module/Entity必须是 `audio_top`，19 IO**。
本机生成 `impl/pnr/audio_core.fs`，用既有SRAM下载方式试听。
构建脚本检查资源、50MHz时序和构建期间源文件一致性，指纹保存在
`impl/build_provenance.json`；正式记录在 `results/validation.json`。
源码、约束、复现脚本随Git同步；比特流、ModelSim库和构建缓存留在本机。

`--fast-rom`只加速仿真：从原始4096项正弦常量生成同步数组，并先比对全部地址、
X/Z保持及连续跳转；综合仍使用原来的RTL。省略此选项可直接仿真原case-ROM。
本轮另有950帧默认钢琴的原ROM/数组整链逐样本对照；加速模型和中间文件不提交Git。
并行模式把五个音色及Lead效果分别复位、分别生成后按固定顺序拼接，保留每段的发声/释放帧数；
它不是一场连续演奏的切换录音。`--jobs 1`可复现原连续场景模式，任一场景失败即不生成有效记录。

可选全接口资源审计：

```powershell
python project/audio_core_v1/experiments/interface_audit/build_audit.py
```

该审计保留主机/ADC/状态端口，**仅综合，不可作为板级顶层布局布线或下载**。

## 尚未合入

当前19针顶层把外部主机和ADC置为空闲；没有SPI驱动或新J13分配。
真实25键/控制PCB、显示/蓝牙CDC和整机约束仍待接入。
`audio_core`的25键逻辑适配已仿真；当前16个物理矩阵键是两个白键区的验证替身。
Drive lead为新声部滑入，尚无不重触发包络的单声部legato模式。
旧尖锐伴音的根因、实际模拟延迟和新固件听感均不能由仿真代替。
已板测的 `final_dual_timbre` 保持回退。
