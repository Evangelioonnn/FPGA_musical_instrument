# Playable timbre gallery V1

首轮用户试听已完成，逐音色结论见[板测记录](../../evidence/timbre_gallery_2026-09-27/BOARD_LISTENING.md)。拨弦、Drive lead、铃音获可选音色认可；部分音色存在音区响度差异和尖锐声，尚未完整验收全部控制功能。下文未板测描述为生成时状态。

This is A's eight-preset listening candidate, built as **one Gowin project and one bitstream**. The user-approved piano and warm pluck are retained; organ, pad, two leads, electric keys and metallic bell are new FPGA synthesis experiments. They are not recordings or an imported OPL2/STK core. The implementation contract is in [SPEC.md](SPEC.md); physical listening has not yet qualified the new presets.

Open [timbre_gallery_v1.gprj](variants/timbre_gallery_v1/timbre_gallery_v1.gprj) in Gowin Designer and confirm top module `timbre_gallery_v1`. Build output is `variants/timbre_gallery_v1/impl/pnr/timbre_gallery_v1.fs` for the existing SRAM Programmer flow. The `impl` directory is local/generated and is intentionally not committed. The prior [00_control project](../audio_output_lab/variants/00_control/00_control.gprj) remains the independent rollback, with the two already heard presets.

The board connection is unchanged from [the matrix wiring](../input/matrix_playable/WIRING.md): passive 4x4 matrix on PMOD1/J8, encoder A=T18/B=R17 with 3.3 V and GND (C unconnected), audio via the board 3.5 mm jack. The board's three user buttons need no new wiring. The keyboard is two groups of eight white notes, initially C3-C4 and C4-C5. It is an input prototype, not the planned full two-octave product control surface. See [BOARD_TEST.md](BOARD_TEST.md) before downloading.

## Local reproduction

```powershell
python project/timbre_gallery/tools/generate.py
python project/timbre_gallery/sim/run.py
python project/timbre_gallery/tools/check_math.py
python project/timbre_gallery/tools/render.py
python project/timbre_gallery/tools/build.py
```

`run.py` uses ModelSim, `build.py` uses Gowin `gw_sh.exe`; each accepts an explicit local tool path. `render.py` writes short stereo WAVs from the actual eight-voice RTL mix before master volume gain. They are for comparison on a computer and are never read by the FPGA. Current result levels, timing and bitstream hash belong in [VALIDATION.md](VALIDATION.md); numerical, PnR and actual board listening are separate gates.

The bank has eight independently identified slots. Changing preset or octave while a key is held affects subsequent strikes only. A full bank rejects a new strike without reducing or stealing existing voices. Piano and pluck must retain exact old raw PCM; the other six candidates need user listening, especially high-volume low-register chords and the remaining pitch-following noise. Display/Bluetooth and the final B control PCB are outside this standalone audio candidate.
