# Looper第二轮改进证据 · 2026-10-07～08

角色A；分支 `codex/looper-refinement-20261007`；比较commit `0199ed7`。成果在 [looper_refinement_lab](../../project/looper_refinement_lab/README.md)，原Looper与已认可V2保持回退。本轮尚未收到板测，不继承V2的试听资格；未推送远端。

| 证据 | 入口及范围 |
|---|---|
| 必需数字回归 | [40项结果](../../project/looper_refinement_lab/results/regression.json)；每项bench、源SHA和PASS在results/sim、results/unit |
| 完整能力矩阵 | [VALIDATION](../../project/looper_refinement_lab/VALIDATION.md)；表达/生命周期、实际参数保护、32旋律+8鼓、2048事件、ADC/pickup/CDC分别记录 |
| 独立19针50MHz候选 | [BUILD](../../project/looper_refinement_lab/results/final_50mhz/BUILD.json)：33466 Logic / 17075 Register / 23673 CLS / 75 BSRAM / 31.5 DSP，setup/hold 0/0，最差余量0.018ns |
| 额外18ns guard | [历史失败](../../project/looper_refinement_lab/results/final/BUILD.json)，21 setup违例，-0.466ns，不可作为合格固件 |
| 默认接口审计失败 | [18ns失败](../../project/looper_refinement_lab/audit/results/final_audit/FAILURE.json)：300未布网；[20ns失败](../../project/looper_refinement_lab/audit/results/final_audit_50mhz/FAILURE.json)：333未布网；放置占用不代表成功PnR |
| 复位/PLL审计失败 | [基础LOCAL_CLOCK](../../project/looper_refinement_lab/audit/results/local_reset_50mhz/FAILURE.json)：272未布网；[PLL拓扑](../../project/looper_refinement_lab/audit_pll/results/pll_50mhz/FAILURE.json)：3402未布网、41005Logic/22760Reg/26449CLS/79RAM/31.5DSP/1PLLA，没有合格STA/FS |
| PLL wrapper模型 | [CLOCK_MODEL](../../project/looper_refinement_lab/audit_pll/results/CLOCK_MODEL.json)：行为150MHz/Lock启动、失锁和恢复PCM通过；不是供应商原语仿真或物理锁定/STA证明 |
| 参考音 | [9 WAV清单](../../project/looper_refinement_lab/results/preview.json)；2当前源preview bench通过，WAV/原PCM逐字节回读；WAV在本机重建 |
| 板测与接线 | [BOARD_TEST](../../project/looper_refinement_lab/BOARD_TEST.md)；SRAM、19针，原矩阵/EC11/三键，无新外接线 |
| C接入 | [LR1真实接口](../../project/looper_refinement_lab/INTEGRATION.md)；状态54字、最终PCM、ACK owner、复位/背压模型。不含实际C UI/FFT/蓝牙/TMDS；PLL探针物理失败 |
| 批准计划 | [WORK_PLAN](../../project/looper_refinement_lab/WORK_PLAN.md)，条件40槽及tap/细分未采纳 |
| 最终分层资格 | [BOARD_DELIVERY](../../project/looper_refinement_lab/results/BOARD_DELIVERY.json)：当前源/FS/PCM/WAV核对；独立板候选true、接口false、整机false。严格完整collect实际拒绝失败审计，无合格DELIVERY |

原固件SHA：`d81a4941539ca4c02f25b2bf596c20951a0e884e3ed9465630e76b7c5c126b1c`。
新19针FS SHA：`ce06b7105a62f311cabbab9cb972bef0f680282afb895f4fb799b025f8828a3d`。

全局节拍器可独立于Looper，40～240 BPM，2/4、3/4、4/4。201档逐拍数学期望和实际1040周期40/120/240代表档均通过；每拍算法误差不超过一个音频样本，实物晶振误差尚未测量。

保持32共享旋律槽（含12 Warm pluck与全部尾音），另8鼓。32槽不保证32个循环音重触发时还能容纳上一轮32条长尾音；满池拒收，不偷音。四谐波共相位/包络不冒充32个独立振荡器。

本轮普通/选择性延音和弯音按track/layer记录，四谐波patch在实际录音起点冻结。MCP3208、五推子模式pickup与25键生命周期是模型资格，实体ADC/控制板仍待接入。资格以lab最终BOARD_DELIVERY/VALIDATION为准；最终整机须取得C固定源码，优化声部状态/快照、实际关键路径及复位分发，并统一PLL/约束后共同PnR。

数字测试不代替模拟音质、SNR、输入至模拟输出延迟、真实演奏操作及显示/蓝牙整机验收。C预留额度不减少，具体容量及CLS风险见 [统一预算](../../docs/team/RESOURCE_BUDGET_V1.md)。
