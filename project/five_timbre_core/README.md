# Five-timbre performance core

**2026-09-28 audition update:** 用户已认可五音色及四谐波分别调节效果；暂定保留ID 0/2/3/4/5，旧ID 1退出后续菜单。当前固件及以下操作未改变；“待试听”描述为生成时状态。实体ADC及音频/显示/蓝牙整合仍未验证。见[最新试听与选择记录](../../evidence/audio_selection_2026-09-28/BOARD_LISTENING.md)。

This A-owned candidate collects the five user-selected presets in one playable
firmware, with two sound-balancing comparisons. See [SPEC](SPEC.md) for stable
IDs and control semantics, [BOARD_TEST](BOARD_TEST.md) for physical audition,
and [VALIDATION](VALIDATION.md) for the actual completed gates.

Generate projects with `python project/five_timbre_core/tools/generate.py`.
Run RTL checks with `python project/five_timbre_core/sim/run_five.py`.
Build one variant with
`python project/five_timbre_core/tools/build.py --variant five_00_reference`
(likewise `five_01_balance` or `five_02_spectral`). Source
hashes, resources, timing violations and `.fs` hash are recorded under each
variant's ignored `impl/build_provenance.json`. The three variant projects
share only source and controls; each has its own bitstream.

The `sim/render_results.json` and `sim/audio/` outputs come from actual RTL
rendering with `python project/five_timbre_core/tools/render_five.py` after
`run_five.py` compiles the work library. Four retained presets are compared
with previously archived gallery PCM hashes. The original pluck is compared
frame by frame with the older `final_bank` in a separate testbench.

This candidate has not been listened to on the board or integrated with C's
display and Bluetooth. The independent gallery and original dual-timbre
firmwares remain useful rollback points.
