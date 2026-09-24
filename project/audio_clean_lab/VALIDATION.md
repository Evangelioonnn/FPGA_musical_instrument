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

## 尚未验证

- 四个 `.fs` 尚未由用户完成新的板卡试听。
- 真实尖锐声是否因候选音色而降低尚未确定。
- 仍没有示波器波形，因此不能区分数字输出、PT8211、LMV321、NS4263 和耳机接口的第一处异常。
