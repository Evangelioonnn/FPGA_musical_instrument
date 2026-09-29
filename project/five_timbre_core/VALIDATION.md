# Five-timbre candidate validation

**2026-09-28 audition update:** 用户已认可五音色及四谐波分别调节效果；暂定保留ID 0/2/3/4/5，旧ID 1退出后续菜单。当前固件及以下操作未改变；“待试听”描述为生成时状态。实体ADC及音频/显示/蓝牙整合仍未验证。见[最新试听与选择记录](../../evidence/audio_selection_2026-09-28/BOARD_LISTENING.md)。

Date: 2026-09-28

Owner: A

Branch: `codex/five-timbre-night`

This is a digital candidate for the Tang Mega 60K + NEO Dock. **The user reports acceptable sound and tested controls across the five
presets, with no large audible difference among 00/01/02.** The tested
`final_dual_timbre` build remains the physical rollback point. A passing RTL
test, PnR, or rendered WAV does not establish board audio quality or fix the
known pitch-related sharp noise.

## RTL and audio checks

From the repository root:

```powershell
python project/five_timbre_core/sim/run_five.py
python project/five_timbre_core/tools/render_five.py
```

The following benches passed on 2026-09-28:

| Check | Result |
|---|---|
| `five_core_tb` | Five preset dispatch, selective sustain, Drive lead bend/glide, and eight occupied voices passed; 3,809 frames observed |
| `five_board_tb` | Matrix, panel buttons, encoder, two-zone note identity, ghost recovery, PT8211 words passed; 1,300 stereo words, 1,012 nonzero |
| `five_original_pluck_tb` | 1,209 sampled output frames exactly match the original `final_dual_timbre` pluck implementation |
| `five_balance_tb` | Piano/lead balance and spectral changes checked; Metallic bell remains fixed |
| `five_range_tb` | 25-key mapping, zone/config snapshots, repeated pitch identity, boundaries, queue stall, ghost and overflow checks passed |
| `five_capacity_tb` | 16 mixed voices functionally rendered for 406 frames without clipping/deadline failure |

The renderer produced 11 variants of 80,100-frame stereo WAVs at 48,077 Hz. For unchanged
gallery presets, PCM hashes matched the archived gallery outputs. The
reference piano C3/C5 RMS was 785.15/785.45; balance mode 01 changed it to
785.15/638.19, and mode 02 to 785.15/631.83. Drive lead changed from
1154.82/1155.81 to 1154.82/939.10 (01) and 1154.82/928.20 (02). Metallic
bell's PCM hash is identical in all three modes. The original pluck has its
own exact-frame RTL regression against the previously tested implementation.

Rendered files are local, ignored simulation products under `sim/audio/`;
they are not part of the source commit. The board audition sequence and
controls are in [BOARD_TEST.md](BOARD_TEST.md).

## Three board-build candidates

Command:

```powershell
python project/five_timbre_core/tools/build.py --variant all
```

Tool: Gowin EDA V1.9.12.03 (64-bit), target GW5AT-LV60PG484AC1/I0, Device
Version B. All three builds completed, generated `.fs` files, and reported
zero setup and hold violated endpoints. Their actual Fmax exceeds the 50 MHz
clock constraint. Resources are from each candidate's post-PnR report.

| Variant | Logic | Register | BSRAM | DSP | I/O | Min setup slack | Fmax | Bitstream SHA-256 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `five_00_reference` | 21,105 | 9,405 | 34 | 68 | 19 | 1.089 ns | 52.878 MHz | `a51d4493efe0264ebfeaf0e3fb7e3f7724877bc280ebdc3529898c05ee8e605d` |
| `five_01_balance` | 21,232 | 9,461 | 34 | 69 | 19 | 1.062 ns | 52.804 MHz | `b06d1efe0fcbc6fda12d8f97456c2d4268114fc560389fc05b65a7d24ac814b1` |
| `five_02_spectral` | 21,365 | 9,461 | 34 | 69.5 | 19 | 0.884 ns | 52.311 MHz | `16b7ecb47f08c562df6fd580fc137ba1aa80243656219ae5a6e0dc21ae9bada8` |

The audio-plus-input design budget is 29,000 Logic, 17,000 Register, 70
BSRAM, and 78 DSP. All candidates fit that allocation. Even the largest
candidate leaves 7,635 Logic, 7,539 Register, 36 BSRAM, and 8.5 DSP within
that allocation. Against the separate C allocation, the largest candidate
plus the reserved input/C allocations (2 BSRAM + 2 DSP and 26 BSRAM + 16 DSP)
would total 62 BSRAM and 87.5 DSP. This is a budget check, not a combined
audio/display/communication PnR result. IO banks, pin collisions, and full
system timing still need a coordinated integration build.

The Gowin console includes width-truncation warnings (`EX3791`) and a
`PR1014` generic clock-routing warning for the 50 MHz clock. The warnings did
not create setup/hold violations in these reports, but they are not silently
treated as proof that every warning is harmless. The common V22 clock and
PR1014 context are documented in [BOARD.md](../../docs/board/BOARD.md). Each
new top-level integration must be re-run through synthesis, PnR, and STA.

## 16-voice resource probe

`experiments/capacity16` is an unpinned capacity experiment, not an SRAM
download image. Its functional 16-voice bench passed. Synthesis estimates
53,053 Logic (89% of device),
17,121 Register, 49 BSRAM, and DSP primitives `54 x MULTALU27X18` plus
`32 x MULT27X36`. This exceeds the A+input Logic allocation by 24,053 and
leaves too little room for C; do not treat it as an integration-ready
16-voice path.

The PnR process was stopped after routing remained at Phase 0 (60%) for a
prolonged period. There is no final PnR or timing result for this probe, so it
is neither a successful implementation nor a timing failure. Keep eight
voices as the current candidate and retain this as a resource-boundary result.

## Not yet verified

- No `five_timbre_core` bitstream has been auditioned on the physical board.
- The new warm pluck, bell, piano balance/spectral modes, sustain semantics,
  and Drive lead expression need user listening and control checks.
- The known pitch-related sharp noise has not been diagnosed or fixed here.
- This candidate has not been combined with C's HDMI/display or Bluetooth RTL.
- The physical input remains the existing 4x4 matrix; 25-key/two-zone support
  is digital adapter coverage only.
- Final timing, pin allocation, and resource use must be regenerated after
  full-system integration.
