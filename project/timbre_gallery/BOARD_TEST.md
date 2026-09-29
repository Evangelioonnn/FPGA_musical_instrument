# One-bitstream listening guide

Use the unchanged matrix/encoder/headphone connections in [WIRING.md](../input/matrix_playable/WIRING.md). In Designer, open this folder's `timbre_gallery_v1.gprj`, verify top `timbre_gallery_v1`, and load this folder's `impl/pnr/timbre_gallery_v1.fs` with the same SRAM mode that worked before. Do not select the old `00_control.fs`. Start at a comfortable external playback level. Power-cycle or redownload to restore preset 0, volume index 18, both zone bases and all controls.

## Controls

| Physical control | Action |
|---|---|
| Board S1 / USER_BUTTON2 | Advance preset 0 through 7, then wrap to 0. Only new notes use the new sound. |
| Board S2 / USER_BUTTON1 | Toggle ordinary sustain. It holds piano/organ/pad/lead releases, while warm pluck and the naturally decaying electric/bell sounds remain natural. |
| Board S4 / USER_BUTTON0 short press and release | Cycle encoder mode: volume, left-zone octave, right-zone octave, release, glide, then volume. |
| Board S4 held about one second | Smooth global stop; release all keys before resuming. |
| EC11 rotation | Change the selected setting with saturated endpoints. Encoder press/C contact is unused. |

The LED uses blue=piano, green=pluck, cyan=organ, amber=pad, white=clean lead, red=drive lead, magenta=electric keys, violet=bell. It blinks differently in non-volume modes and can show fault/voice refusal; use the count of S1 presses as the definitive preset identity. The two S1/S2 names on the **matrix** are different physical buttons.

Preset order:

| S1 presses after reset | Sound | Useful listening check |
|---:|---|---|
| 0 | Precision harmonic piano | Reference articulation and release, compare with the previous 00_control. |
| 1 | Warm pluck | Natural fade; S2 and release setting should not stretch it. |
| 2 | Organ | Stable held note and a clear release when the key lifts. |
| 3 | Pad | Slower onset and sustained body; compare release settings. |
| 4 | Clean lead | Hold one note, start a second, and compare glide off/on. |
| 5 | Drive lead | Same glide test, with a harder timbre. It is a synthesis candidate, not a sampled electric guitar. |
| 6 | Electric keys | Naturally decaying phase-modulated tone; release shortens its tail. |
| 7 | Metallic bell | Brighter phase-modulated decay; release shortens its tail. |

The first short S4 press selects left octave; another selects right octave; a third selects release; a fourth selects glide. In glide mode the initial value is off. Each clockwise step increases slide duration (approximately 21, 43, 85, 170 ms for settings 1-4); setting 0 is off. Glide affects **new lead notes only when another lead note is still held**, and never retunes that old note. Release changes harmonic/lead or electric/bell tail behavior; it is not a pluck sustain control. Rotate S4-mode settings cautiously because the RGB LED is the only mode cue in this prototype.

## Listening sequence

For each preset, first play matrix S9 (C4), S1 (C3) and S16 (C5), then same-row pairs S9+S10 and S9+S11. The matrix is undioded: three rectangle corners may trigger ghost protection and stop sound; choose same-row combinations for multi-note checks. The initial two rows of each zone play white-key sequences; changing the octave affects new strikes only. Keep the same headphone/speaker level and volume-index setting when comparing presets. Do not compensate a quiet preset by changing the board volume and then assume the noise comparison is still level-matched.

Record for each preset: preferred character, natural/unnatural tail, extra pitched sharp sound, onset click, low-note two/three-note beating, and acceptable volume range. For the two lead presets, also report whether glide sounds natural and whether rapid new notes make an extra transient. For organ and pad, report whether held notes remain stable. The prior user listening found residual pitched sharp noise and some high-level low-register problems in earlier candidates; this firmware has **not** been heard on the board yet.

If the new candidate misbehaves, reopen the prior [00_control](../audio_output_lab/variants/00_control/00_control.gprj) and load its own `.fs`. The 00 reference itself still has residual audible noise, so rollback is a functional comparison, not a claim of perfect analog output.
