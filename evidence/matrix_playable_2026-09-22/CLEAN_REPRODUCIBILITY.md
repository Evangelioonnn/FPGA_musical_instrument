# 干净导出复现

从本仓库暂存区导出到 `tmp/matrix_clean_20260922`，没有复制原工作区的 ModelSim library、生成日志或 Gowin `impl`。仓库完整性检查通过：

```text
REPOSITORY_CHECK_PASS files=569; links, gprj/include dependencies and reference hashes checked
```

在导出目录运行九项短回归（ModelSim 路径使用同一台机器的安装目录）后，以下关键结果通过：

```text
BUTTONS_TB_PASS debounce=1 cycle3=1 separate_release=1 long_once=1 volume_bounds=1
KEYS_TB_PASS events=12 repeat_identity=1 stable_backpressure=1 ghost_overflow_panic=1 token_wrap_blocked=1
NUMERIC_TB_PASS default_reference_exact=43250 default_fm_exact=43250 fm_lengths=8 samples=247897
BANK_TB_PASS frames=5670 accepted=9 rejected=2 identity=1 fixed_gain_mix=1 pluck_ignores_off=1
MATRIX_ALL_TB_PASS electrical_states=65536 changes=2342
INPUT_PHASE_TB_PASS physical_keys=16 transitions=32 scan_latency_ns_min=1453400 max=1730680 debounce_pulse_rejected=1
EVENT_PHASE_TB_PASS real_sample_phases=1040 exact_reference_checks=9425
BOARD_TB_PASS serial_frames=2552 nonzero=904 detents=2 digital_input_latency_ns=1807030 real_scan_timing=1
LED_TB_PASS words=8 widths_18_35=1 grb_order=1
```

在同一副本执行 `tools/generate_fm.py` 和 `tools/create_project.py` 后，生成的 `playable_fm_voice.v` 与 `matrix_playable.gprj` 文本与导出文件一致（`GENERATOR_REPRODUCTION_PASS fm_source=exact_text gprj=exact_text`）。这证明工程依赖没有隐含在原机的 GUI 文件列表中。

完整三音色渲染耗时较长，单独在原工作区并行执行；其源文件、参数、日志和音频指纹由 `validation.json` 绑定。`.fs` 重新构建，不从证据包复制。
