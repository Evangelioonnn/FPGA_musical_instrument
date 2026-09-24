# audio_clean_lab 候选音色证据

对应分支：`codex/audio-clean-lab`。这是 2026-09-24 夜间任务的独立候选工程，不替换正式整机。

四个版本均完成 `clean_voice_tb`、`clean_render_tb`、Gowin 综合、布局布线、15 IO 和 50 MHz setup/hold 检查。构建资源与比特流 SHA256 见本机 `project/audio_clean_lab/impl/*_build_provenance.json`；`.fs` 按仓库规则不提交 Git。

候选的共同输入是 4×4 矩阵和 USER_BUTTON2，timbre 1 保留已知拨弦，timbre 2 保留旧 FM。timbre 0 分别使用原正弦高电平、低阶加法波形、低复杂度双谐波波形和三角波。

## 当前结论

仅有 RTL/PnR 证据，四个版本尚未完成用户板上试听。不能写成“噪声已修复”。板测应按工程内 `BOARD_TEST.md` 在相同输出设备和相同音量下进行。
