# Looper session V2 验证记录 · 2026-10-10

工作在原`D:\uestc\SCM\GowinFPGA`，共享分支`codex/keyboard-pcb-review-20261005`，源码比较起点7fa114b；未切分支覆盖其他窗口工作、未推GitHub。新lab直接位于project/looper_session_v2。旧源和回退FS按BASELINE指纹核对，不覆盖旧音频/板卡/PCB。

用户授权按首轮鼓反馈改版，并先准备C的屏幕接口，后续与C再接真实屏幕。本轮交付：修订鼓组、直接动作/ACK、真实LU1状态和PCM、解包/字段/mock示例、9参考WAV、19针可烧候选及重复验证脚本。

48项必测＋2预览＋鼓整数模型/示例通过；36864个冻结鼓PCM对照、147456个独立鼓数学对照、1024个8筒线性混音对照。真实命令→录制→undo/clear→音频/状态和异步恢复通过，细节见[VALIDATION](../../project/looper_session_v2/VALIDATION.md)和其results指纹记录。

独立板50MHz33676Logic/17123Reg/23771CLS/75RAM/32.5DSP，setup/hold0/0、1.117ns。完整保留接口最终审计已路由但setup41、-0.368ns，不授予50/150MHz物理资格；C真实PLL/UI/TMDS/蓝牙及新6×6控制板均未并入。预算继续保留C额度，未扩大声部或压缩其资源。

新鼓听感尚待用户上板；复杂Looper交互待接C可视化，不把原基本循环听感认可写为本轮新复杂交互通过。满池hat choke替换可能有突变、模拟噪声/SNR/延迟仍待测。原始证据入口：`project/looper_session_v2/results/BOARD_DELIVERY.json`、`SOURCE_MANIFEST.json`、`DRUM_MATH.json`、`regression.json`、`preview.json`及PnR分阶段报告；[上板指导](../../project/looper_session_v2/BOARD_TEST.md)，[C交接](../../project/looper_session_v2/C_HANDOFF.md)。
