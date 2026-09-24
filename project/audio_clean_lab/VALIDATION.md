# audio_clean_lab 验证记录

分支：`codex/audio-clean-lab`。角色：A。范围：独立音色候选，不改正式整机。

## RTL

命令：

```powershell
& ./project/audio_clean_lab/sim/run.ps1 -ModelSimBin 'E:/QuartusII/modelsim_ase/win32aloem' -WorkLibrary work_audio_clean -Benches 'clean_voice_tb,clean_render_tb'
```

结果：`CLEAN_VOICE_TB_PASS`、`CLEAN_RENDER_TB_PASS`。四种模式均产生有效非零样本；渲染测试未发现仿真错误、空输出或异常终止。电脑 WAV 只用于检查数字输出，不代表板卡模拟音质。

## Gowin 50 MHz PnR

四个候选均完成 15 IO、比特流生成和 setup/hold 违例检查。资源和最差余量以对应 `impl/*_build_provenance.json` 为准；所有构建仍保留 PR1014 通用时钟路由警告。

| 候选 | Logic | Register | BSRAM | DSP | IO | PnR |
|---|---:|---:|---:|---:|---:|---|
| reference_x8 | 约 23k | 约 9.6k | 40 | 97 | 15 | 通过 |
| harmonic_piano | 约 23.6k | 约 9.6k | 64 | 97 | 15 | 通过 |
| low_fm | 约 23k | 约 9.6k | 48 | 97 | 15 | 通过 |
| triangle | 约 23.2k | 约 9.6k | 32 | 97 | 15 | 通过 |

## 2026-09-24 用户板测

四个 `.fs` 均已由用户下载试听，矩阵输入和音色切换可用。结果与 `BOARD_TEST.md` 一致：

- `harmonic_piano` 听感最好，颤音比另外两个谐波候选弱，仍有一点随音高变化的尖锐成分，但当前音量下可接受。
- `triangle` 几乎听不到尖锐声，整体更响，但音色明显偏数字化。
- `reference_x8` 与 `low_fm` 音色相近，类似旧默认且比旧默认更好；相邻音符偶尔有颤音，低音时更明显。
- 四版的静音底噪没有明显差别。用户未报告新的起音、松键或复音故障。

这说明候选波形确实能改变主观高频成分，但没有证明公共模拟链路已经正常。用户提出的“尖锐声可能是合成谐波”的判断是合理假设：它需要与基频同步变化，并在不同波形候选中强弱不同；仍需频谱或分级示波器测量确认。

## 尚未验证

- 没有示波器波形，因此不能区分音色本身的谐波、实际数字输出、PT8211、LMV321、NS4263 和耳机接口中的第一处异常。
- 还没有用固定音程序列测量相邻音颤音是否等于两音频率差产生的拍频。
- `harmonic_piano` 尚未合入正式 `matrix_playable`；它目前只是主音色候选。
