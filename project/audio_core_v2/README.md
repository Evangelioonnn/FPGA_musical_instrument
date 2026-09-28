# 音频核心 V2 · 32声部共享架构

A负责，分支 `codex/audio-core-v2`，基线 `615cb94`。本轮新增目录，V1及旧final保持可回退。
用户已认可V1和独立钢琴16/32复音；**本目录新固件仍需用户板测**。

唯一正式入口是本目录 `audio_v2.gprj`，顶层 **audio_v2_top，19 IO**。
生成的SRAM下载文件是 `impl/pnr/audio_v2.fs`，实际指纹见 `impl/build_provenance.json`。
不要下载 `variants/` 或 `experiments/` 中的中间候选。

## 本轮变化

- 钢琴0、铃音3、Drive lead4、自定义5各可使用全部32个逻辑声部；Warm pluck2最多12声部。
- 五音色与旧尾音共用32个全局槽位，不是32+12同时可闻声部。容量满时拒收新音，不偷音。
- 每次击键保留独立身份、相位/音高/包络；两种延音、双区移八度、Lead滑入/弯音/颤音、ADSR和房间效果沿用V1操作。
- 谐波音色每音固定为V1的1/4，Warm pluck保持V1电平；增加新音不会按活跃声部数量压低旧音。请在相同主音量下比较。
- 声部状态存RAM，一套共享渲染器及共享拨弦算子分时计算；不复制32套完整音色核心。
- 为C提供V2能力表、32声部状态和同沿扩展快照；真实SPI ADC、HDMI/蓝牙及其CDC仍未接入。

阅读[操作与验收](BOARD_TEST.md)、[规格](SPEC.md)、[验证](VALIDATION.md)、
[接口V2](../../docs/interfaces/AUDIO_CORE_V2.md)。板卡接线保持V1原样。

## 复现

在仓库根目录运行，脚本支持 `--modelsim` / `--gowin` 指定本机工具：

```powershell
python project/audio_core_v2/sim/run.py
python project/audio_core_v2/sim/run.py --test v2_pitch32_tb
python project/audio_core_v2/tools/headroom.py
python project/audio_core_v2/tools/build.py
python project/audio_core_v2/tools/audit.py --inputs
python project/audio_core_v2/tools/render.py --jobs 2
python project/audio_core_v2/tools/record.py
python tools/check_audio_evidence.py
python tools/check_repository.py
```

`audit.py --inputs`为仅综合顶层，保留25键逻辑、全部host/ADC/状态/PCM端口，
以及当前矩阵扫描、EC11、DAC发送器和指示器。其几千个观察端口不是外部IO，不能PnR或下载。
未来控制板扫描器、SPI ADC与C的完整实现合并后仍须重跑整机资源和时序。

参考音频来自真实1040时钟节拍的RTL PCM，使用已逐地址验证的同步数组正弦ROM加速仿真；
综合仍用原case-ROM。不作峰值归一化，参考主音量固定Q16=65536；板卡启动仍为18档8249。
WAV、比特流、ModelSim库和impl缓存留在本机，源码、必要配置及证据摘要进入Git。

## 目录分区

| 目录/文件 | 用途 |
|---|---|
| `src/audio_v2_bank_stream.v`、`audio_v2_tone.v`、`audio_v2_pluck.v`、`audio_v2_pool_slot.v` | 正式共享架构 |
| `src/audio_v2_core.v`、`audio_v2_top.v`、CST/SDC | 参数/效果/状态整合及现有19针上板适配 |
| `sim/`、`tools/`、`results/validation.json` | 可复现测试、构建与本轮证据 |
| `audio/` | 本机RTL参考WAV；不是板卡模拟录音 |
| `variants/`、`experiments/`、其他bank/slot/state文件 | [架构探索历史](experiments/README.md)，不作为验收入口 |

四谐波共用单声部相位和包络，不能将32声部称为128个独立振荡器。
物理16键无二极管矩阵限制实际和弦，不代表逻辑只支持16声部。
不宣称模拟尖锐伴音根因已修复；新的音色听感及32/12复音需实物验收。
