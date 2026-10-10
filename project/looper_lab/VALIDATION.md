# 当前修复候选的验证与构建

日期2026-10-07；分支 `codex/looper-drum-night-20261007`。这是独立候选，**尚未用户板测，不替换audio_core_v2**。本页对应当前源，旧缩减版撤回记录见[REVIEW](REVIEW_2026-10-07.md)。

## 最终完整顶层PnR

Gowin V1.9.12.03，GW5AT-LV60PG484AC1/I0 / GW5AT-60B；`looper_top`；32旋律槽、12拨弦物理槽、16事件lane、8鼓槽、短房间、全局点击、现有矩阵/EC11/三键；19实物IO。运行 `python project/looper_lab/build_delivery.py`。

| 项目 | 最终结果 |
|---|---:|
| Logic | 32251 / 59904 |
| Register | 16254 / 60780 |
| CLS | 22780 / 29952 |
| BSRAM | 86 / 118 |
| DSP | 33.5 / 118 |
| IO | 19 |
| Setup/Hold违例端点 | 0 / 0 |
| 最小setup余量 | 0.029 ns |
| Fmax | 55.644 MHz |

**SDC使用18ns目标，实物时钟仍为50MHz/20ns。** 18ns报告的0.029ns不能改称“50MHz报告余量0.029ns”，也不能保证加入C后的结果。保留PR1014：`sys_clk_d`使用generic routing。无需把8条PRIMARY/LW资源误报为8个真实时钟域；将来合并必须重新评估时钟布线和偏斜。

固件 `impl/pnr/looper_lab.fs` SHA-256：

```text
d81a4941539ca4c02f25b2bf596c20951a0e884e3ed9465630e76b7c5c126b1c
```

源/约束/GPRJ/构建脚本指纹见 `results/final/BUILD.json`，构建过程输入一致性检查已通过。完整报告保留本机 `results/final`；Git提交精简JSON。阶段A/B/C见 `results/HISTORY.json` 与对应source JSON，只是中间探索，不继承当前功能资格。源码修改后必须重新运行构建，不能沿用此哈希。

## 数字验收项目

统一入口 `python project/looper_lab/sim/regress.py --jobs 3`；最终当前源结果/哈希以 `results/DELIVERY.json` 为汇总入口（生成命令 `python project/looper_lab/collect_evidence.py`）。逐项机读记录位于 `results/sim`，每项包含测试bench及依赖源指纹。

| 类别 | 检查 |
|---|---|
| 节拍与点击 | 40/120/240一分钟模型；所有201档BPM逐拍数学期望；1040实际音频周期代表档；点击真PCM/重拍/拍号；下一拍调速；点击关闭不改运行相位 |
| transport/store | 完整一小节预备拍、边界录音/叠录、量化、自动补松键、撤销/清空/取消/溢出原子性、回绕时阻塞包稳定 |
| 容量和路由 | 4轨×4层×128事件全部2048重放、随机背压、同音/轨/层实例身份、bank接受后建映射、被拒鼓击打不录入 |
| 冻结参数 | 自定义PCM对照；上游命令元数据污染不影响已接收事务；现场系数/踏板变化不改变循环层；循环松键不被现场延音扣住 |
| 原V2对照 | 0/2/3/4/5现场及冻结默认参数，逐字4000 PCM比较；原V2 bank/tone/pluck/pool源只在临时库重命名，未修改原源码 |
| 32音高和截止 | MIDI36～67独立十二平均律/相位期望；混合四种谐波和全自定义32；最坏bank渲染653/1040时钟 |
| 整条音频满载 | 32自定义旋律＋8鼓尾音＋点击＋房间＋主音量unity，最终PCM最大渲染680/1040，无截止/路由/鼓拒收错误；场景峰值13707 |
| 幅度压力 | 8同音四系数全满峰13241、无clip；32同音默认峰17243、无clip；32同音四系数全满应正确报告bank限幅，见对应JSON |
| 真实顶层 | 启动、实物矩阵信号模拟到PCM、六项菜单、鼓pad、旋律/鼓层录制回放、停止映射清理、全局点击开关；N32/P12/1040周期 |
| 操作和混音 | 旋钮/按键菜单、端点、轨增益独立、拍号/长度锁、click/drum同拍都送出、主音量0覆盖全部来源，点击不进录音 |

顶层bench仅加速/force音乐tick/beat/bar使循环测试可完成，扫描和音频保持1040周期；其结果不能代替真实BPM准确性测试，准确性由独立clock/click测试覆盖。32容量压力不是“现有无二极管矩阵可同时按32键”的证明。

为避开旧ModelSim对大case ROM的性能限制，默认复用既有 `project/audio_core_v1/tools/sim_rom.py`。每次先比对4096地址、8种X/Z、2048跳址和初始值，再仅在仿真库替换精确同步数组ROM。生产RTL、GPRJ和Gowin ROM未改变；来源/检验写入各JSON。`--case-rom`可复现原literal case路径。历史 `metronome_delivery_audit_tb` 是坏拓扑复现，不列入当前正向验收。

## 参考音

`python project/looper_lab/sim/preview.py` 生成五个音色、16鼓pad顺序和120BPM节拍器WAV，位于 `sim/audio`；哈希/样本数/原峰值/试听增益见 `results/preview.json`。bank N1/P1干声、主音量前、逻辑Fs=50000000/1040，仿真CE64加速；每文件固定增益将峰值调整到15000，WAV元数据48077Hz。无压缩器/声部数归一化，预览增益不用于固件。它不是完整顶层相同电平音频，也不证明1040截止或模拟音质。

## 资源与未验证范围

C预留13k Logic/10k Reg/26 BSRAM/16 DSP/1 PLL不变。标量相加当前候选+C全额度为45251 Logic/26254 Reg/112 BSRAM/49.5 DSP；剩余14653/34526/6/68.5。当前CLS已占22780，余7172；C预算13k Logic的理想最低就需要约6500 CLS，不能只看Logic剩很多就判断可放下。真实ADC/新增输入/正式传输以及C均未并入，6块RAM余量必须共同规划，见[预算](../../docs/team/RESOURCE_BUDGET_V1.md)。

尚未确认：实体听感及模拟杂音/SNR/延迟、实体推子/25键/踏板、多轨演奏压力板测、显示/蓝牙合并、连续自动化、TF保存、鼓choke点击听感。32自定义全系数全满存在限幅边界；详见SPEC，不伪装成全组合无削波。实物下载步骤见[BOARD_TEST](BOARD_TEST.md)。
