# 首次仓库交接的复现检查

日期：2026-09-19。此次只整理仓库、资料和说明，未改动音频RTL/约束或算法。

结果：仓库链接、Gowin工程依赖、Verilog include及22份原始资料SHA256检查通过；从Git暂存区导出的独立副本在无旧仿真库/样本文本条件下，完成baseline完整仿真。

| 检查 | 结果 |
|---|---|
| baseline_voice_tb | PASS，192308个样本，与原voice/力度参考一致 |
| baseline_mixer_tb | PASS，2000组，其中921组饱和 |
| baseline_tb | PASS，2048帧、48事件、17配置、最多8声部 |
| baseline_render_tb | PASS，769232样本，普通/选择性延音和新音释放检查通过 |
| Python音频分析 | PASS，C4 261.631Hz，音量/力度/静音及电平边界通过 |
| 新生成WAV与发布参考 | raw、preview两份SHA256分别完全一致 |
| 与原音色参考对照 | 另行检查前96154个PCM样本与instrument_original.wav完全一致 |

详细日志、22个构建/仿真输入文件的LF规范化SHA256和结果见[validation.json](reproduced_2026-09-19/validation.json)。导出副本使用ModelSim ALTERA 10.1d；受限环境最初无法创建work库，随后在正常权限下完整运行成功。Python分析只使用标准库。

运行命令与根README相同，将ModelSimBin/PythonExe换为本机路径。干净副本的可选旧文本对比项确实为0；上述96154样本对照是另外读取已发布原WAV完成，不能混淆这两项证据。其它历史工程此轮没有全部重新仿真。

历史Gowin实现报告单独保留；此轮不重跑未改变RTL的PnR，不把历史报告标成本轮新构建。也没有新板测结果。
