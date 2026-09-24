# audio_clean_lab 板测表

日期：____　操作者：____　供电：USB / USB＋12 V　输出：耳机 / 有源音箱

矩阵接线、按键接法和下载流程沿用 [matrix_playable 接线表](../input/matrix_playable/WIRING.md)。每次只换 `.fs`，使用 SRAM Program，不写 Flash。

试听顺序：

1. `audio_clean_harmonic_piano.fs`
2. `audio_clean_reference_x8.fs`
3. `audio_clean_low_fm.fs`
4. `audio_clean_triangle.fs`

每个版本都记录：单音 C4、C4-E4-G4 和弦、相邻音快速连按、松键尾音、静音底噪和音色切换。先在相同外部音量下比较，再把候选和拨弦调到近似响度比较。增益版特别注意过响和削顶。

| 固件 | 单音噪声 | 复音 | 起音 | 松键 | 静音底噪 | 主观结论 |
|---|---|---|---|---|---|---|
| harmonic_piano | | | | | | |
| reference_x8 | | | | | | |
| low_fm | | | | | | |
| triangle | | | | | | |

“更响”不能直接记录为“更干净”。如果所有候选的噪声仍随音高同步出现，应停止软件音色 A/B，进入示波器测量。
