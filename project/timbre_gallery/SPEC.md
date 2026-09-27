# Playable timbre gallery V1

Branch `codex/playable-timbre-gallery`, owner A. Input baseline `0f71e44` plus its user listening feedback. Scope: this lab, focused status/catalog/evidence updates. The previously heard `audio_output_lab/00_control` source and firmware remain an independent rollback. No Flash programming or remote publication.

## Contract

50 MHz; 50 MHz / 1040 audio samples per second; eight token-identified voices; 16-key 8+8 white-key matrix, independent zone octave bases and existing pins. One `.gprj` and one `.fs`. On-board S1 cycles eight presets, S2 toggles ordinary sustain where meaningful, S4 short press cycles volume / left octave / right octave / release / glide; S4 long press panics. Encoder adjusts selected mode. RGB LED identifies preset. All pitch/glide, sound generation, mixing and output happen in FPGA RTL; no note recordings, CPU or host audio. Switching a preset changes new strikes only; existing voices finish in their original preset. No division by active voice count.

| ID | Candidate | Gate and tail | Glide/effects |
|---:|---|---|---|
| 0 | precision piano | preserve previous ADSR and sustain | no slide, dry |
| 1 | warm pluck | independent Karplus-Strong natural decay | no forced sustain/slide, dry |
| 2 | organ | fast attack, constant held level | sustain + release dial |
| 3 | pad | slow attack, held level | sustain + release dial |
| 4 | clean lead | bright harmonic held source | legato portamento on new notes, release dial |
| 5 | drive lead | same pitch behavior, per-voice gentle nonlinear shaping | portamento, release dial; no global distortion of other presets |
| 6 | electric keys | two-operator phase modulation, naturally decaying amplitude/modulation | release dampens tail |
| 7 | metallic bell | deeper 3:1 phase modulation, naturally decaying amplitude/modulation | release dampens tail |

Preset 6/7 are original small FPGA phase-modulation experiments. STK, Rings and OPL2 are algorithm references, not imported or board-qualified cores. Assessing an upstream OPL2 build is a separate diagnostic result; do not call it integrated unless present in this playable `.gprj`, independently tested and budgeted.

Glide affects only new lead strikes. If another lead voice is held, use its current pitch as start, then approach the new note over a configurable 2^10..2^13 audio-frame window. Glide=0 disables it. Existing notes keep their own pitch. Store each new strike's preset, octave and token, so changing controls while held cannot retune/release the wrong note. Continuous pitch correction requires phase-continuous updates, no oscillator restart on each intermediate step. Stale held notes, panic, queue overflow and full eight-voice refusal follow the prior safe behavior.

## Validation gates

1. Old piano/pluck raw PCM against `output_bank(PROFILE=6)` for same notes/releases with glide=0; no unintended gain/tail changes. Selective snapshot/multi-note/preset-switch and release behavior.
2. Independent fixed-point oracle for organ/pad/lead and two-operator candidates. Per-preset real RTL WAV: single C3/C4/C5, chord, held/released tail, new-note glide; no unknown samples, clip, deadline or inaudible preset.
3. Matrix/button/encoder board-top and PT8211 decode; 50 MHz Gowin PnR with resource/timing report. Enforce A+input working ceiling 29000 Logic/17000 registers/70 BSRAM/78 DSP and 19 IO; display/communication reserve remains C's 26 BSRAM/16 DSP.
4. The user alone qualifies sound/controls on the physical board. Record CPU reference versus board separately, especially the remaining pitch-following noise and perceived beating.
