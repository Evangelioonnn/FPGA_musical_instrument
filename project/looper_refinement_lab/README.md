# Looper改进实验 · 2026-10-07

用户批准的独立夜间工程；角色A，分支 `codex/looper-refinement-20261007`，固定比较起点 `0199ed7`。原 `looper_lab` 候选和已认可的V2保留。此目录同时提供现有硬件的试听候选，以及真实ADC/传输的逻辑接入审计，二者资格分别记录。

| 用途 | 入口 |
|---|---|
| 可上板工程 | `looper_refinement_lab.gprj`，Top **looper_refinement_top**，19 IO |
| 可上板固件 | `impl/pnr/looper_refinement_lab.fs` |
| 现有接线、操作与验收 | [BOARD_TEST](BOARD_TEST.md) |
| 功能、数值与限制 | [SPEC](SPEC.md) |
| 无损优化证据、关键路径和整合优先级 | [RESOURCE_REVIEW](RESOURCE_REVIEW.md) |
| 回归、PnR、当前指纹 | [VALIDATION](VALIDATION.md)，[独立板交付清单](results/BOARD_DELIVERY.json) |
| C真实状态/PCM/命令接入 | [INTEGRATION](INTEGRATION.md) |
| 计划与逐项结果 | [WORK_PLAN](WORK_PLAN.md) · [PROGRESS](PROGRESS.md) |

本目录是10月7～8日历史候选；旧比较源码已归入同仓库 `project/looper_lab`，不依赖另一台电脑的工作区路径。最新鼓组与C接口见[looper_session_v2](../looper_session_v2/README.md)。当前硬件依然是4×4矩阵、EC11 A/B、三板载键，不增加接线、不调用编码器按压。

本轮保留32共享旋律槽、其中12个Warm pluck物理槽，以及另8个鼓槽；四轨×四层×128事件。新增普通/选择性延音及有界弯音录放，每层独立。自定义四谐波仍在录音起点冻结，现场持续音可以继续编辑。全局40～240 BPM节拍器继承旧候选，无须启动Looper。

精确四分之一正弦表保留4096地址精度、四个读通道、一拍延迟，全部地址对照；既有五音色默认PCM与V2逐样本核对。不是通过降低采样率、音质、事件容量或C预算换资源。不偷音、不按活跃数归一化。

`refinement_link` 将MCP3208→五推子模式pickup→真实参数/混音服务，与状态、PCM和命令CDC接通。板级19针固件关闭未接的ADC/远端输入；**所有audit工程不可烧录**。audit是27针外部观察时钟审计；audit_pll是26针、复用已板测显示PLL的候选。二者都未包含C的显示UI、FFT、蓝牙UART或TMDS输出，不是整机成品。

本轮完成40项必需回归、2个参考bench、PLL wrapper恢复模型及9 WAV回读。19针实际50MHz PnR通过，75 BSRAM/31.5 DSP，净省11 BSRAM/2 DSP，但最差余量仅0.018ns。四次接口物理审计均失败，最后PLL审计3402网未布通；完整collect已拒绝，最终只生成BOARD_DELIVERY。该固件可用于独立试听，接口/整机资格尚未获得，板测待用户。

从本工作树根运行：

```powershell
python project/looper_refinement_lab/tools/generate_quarter_sine.py
python project/looper_refinement_lab/sim/regress.py --jobs 1
python project/looper_refinement_lab/sim/preview.py
python project/looper_refinement_lab/build_delivery.py --stage final_50mhz
python project/looper_refinement_lab/build_audit.py --variant pll --stage pll_50mhz
python project/looper_refinement_lab/audit_pll/sim/run_clock_model.py
python project/looper_refinement_lab/collect_evidence.py --board-only
```

`--resume` 仅复用源SHA完全相符的PASS。WAV/FS/impl/仿真库留在本机，由脚本重建；WAV不回灌FPGA。听感、实体ADC、模拟延迟/SNR及C整机仍待实测。本目录不是比赛正式发布。

换电脑时，regress.py/preview.py/run.py用 `--modelsim <本机ModelSim目录>`，两份build脚本用 `--gowin <本机gw_sh.exe>`；ModelSim慢机器可调preview的 `--timeout`。机读证据保留当时原文件SHA，最终交付清单另列仓库相对路径的LF规范化源码SHA，便于跨Git换行核对；源码更新后须重跑，不能只重写旧结果的指纹。当前build_audit命令会保留失败证据并返回非零，应先处理接口物理问题；不能把这段命令示例当成所有步骤都通过。

完整collect要求接口审计也通过，路由/STA失败时拒绝生成DELIVERY。若只核对独立板候选，可显式加 `--board-only`，生成独立BOARD_DELIVERY.json并记录接口未合格；它仍要求40项必测、两段参考、全部当前源/FS/PCM/WAV指纹和真实审计失败证据，不产生整机资格。不能把该模式当成功接口审计。
