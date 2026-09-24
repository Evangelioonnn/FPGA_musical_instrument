# audio_clean_lab 规格

- 器件：GW5AT-LV60PG484AC1/I0，50 MHz，15 个物理 IO。
- 输入：原 `matrix_playable` 的 PMOD1 4×4 矩阵和 USER_BUTTON2/Y12。
- 输出：原 PT8211 LSBJ `BCK=Y17`、`WS=AB17`、`DIN=AA16`、`PA_EN=AB16`。
- 复音：八个独立声部；事件、松键、音量、释放和拨弦生命周期沿用候选工程。
- 音色：候选 timbre 0、已知拨弦 timbre 1、原 FM timbre 2。
- 约束：候选必须通过独立 RTL 测试、Gowin 综合/PnR、15 IO 检查和 50 MHz setup/hold 检查后才可板测。
- 禁止：不把电脑 WAV 当作 FPGA 输出，不改 Flash，不把候选直接当成比赛最终固件。
