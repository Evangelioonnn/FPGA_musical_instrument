# Five-timbre playable core contract

Owner A, branch `codex/five-timbre-night`. This is an independent audio/input
candidate for Tang Mega 60K + NEO Dock. The previous `final_dual_timbre`,
`audio_output_lab/00_control` and eight-preset gallery remain rollback baselines.

## Stable preset IDs

| ID | Preset | Source | Sound/control rule |
|---:|---|---|---|
| 0 | Precision harmonic piano | Gallery 0 / palette 01 | ADSR, ordinary and selective sustain, release dial |
| 1 | Original pluck | `final_dual_timbre` pluck | Original limiter/output, independent natural decay |
| 2 | Warm pluck | Gallery 1 / palette 06 | Same physical string model, 1:2:1 output smoothing, natural decay |
| 3 | Metallic bell | Gallery 7 | Naturally decaying phase-modulated tone, key-up damping |
| 4 | Drive lead | Gallery 5 | Held harmonic tone, portamento on new strike, held-note bend, configurable attack/release |

The per-strike 3-bit preset and MIDI note are snapshotted on acceptance. Preset
IDs 5..7 and notes outside MIDI 36..84 are rejected at the bank event port.
Changing the selected preset or zone base never retunes an existing instance. Each key
has a 32-bit nonzero token for note-off. A full eight-slot bank rejects a new
strike without stealing a tail or reducing existing voice levels.

## Timing and controls

- Fabric clock: 50 MHz. Sample enable every 1040 clocks (48076.923 Hz).
- Matrix: 4x4 undioded board input, currently 8+8 white-key locations. The
  independent `gallery_keys` adapter also accepts 24/25 chromatic positions
  split at 12, for future B hardware. This firmware has only 16 physical keys.
- S1 short: advance preset 0..4. S2 short: ordinary sustain. S2 long (~1 s):
  toggle selective sustain and snapshot eligible keys at activation. S4 short:
  encoder mode 0 volume, 1 left octave, 2 right octave, 3 release, 4 glide,
  5 held-lead bend, 6 lead attack; wrap to 0. S4 long: panic with gain ramp.
- Ordinary sustain holds piano and lead key releases. Selective sustain holds
  only piano/lead instances already physically down when toggled on. Both
  controls may overlap; release occurs after both no longer hold the instance.
  Plucks and bell ignore both sustain controls. Panic/fault clears both modes.
- Lead glide starts a *new* lead voice at the newest held lead's base pitch,
  then advances over about 21/43/85/170 ms for settings 1..4. Setting 0 is off.
  Existing held lead notes retain their own base pitch. Held-note bend applies
  globally to active lead voices, in quarter-semitone steps from -2 to +2
  semitones. A single registered Q16 factor feeds the voice bank; each held
  lead slews toward it by 64 Q16 units per audio frame, so
  exiting bend mode returns smoothly to center in at most about 2.6 ms.
- Lead attack index 0..3 maps to ADSR attack increments 128/256/512/1024 per
  audio frame. Index 2 is the original Drive lead behavior. Release setting
  uses the existing indexed 96..1 step table, multiplied by eight for lead.

## Three audio comparisons

- `five_00_reference`: selected five presets, no note-range equalization.
- `five_01_balance`: piano and lead high-register amplitude smoothly
  decrease by 2/256 per semitone above MIDI 48, capped after 36 semitones.
  C3 stays at unity and C5 uses 208/256. Both plucks and bell preserve their
  original output level.
- `five_02_spectral`: same gain curve, plus a gradual reduction of upper
  harmonics on piano/lead using the existing shared upper-partial multiply.
  Bell retains its own bright decay. No frequency-dependent setting is yet
  user-qualified; compare on the physical board at identical volume.

The highest fixed eight-voice sample bound must be rechecked for each new
algorithm. Existing variants attenuate or keep the base signal, so the
original fixed eight-voice arithmetic headroom is retained. There is no
active-voice-count normalization and no prerecorded note samples. Different
voice types share a scheduler; their active state and mutable pluck memories
remain per voice. C's 26 BSRAM / 16 DSP allocation remains reserved.

## Integration boundary

Source interface: `gallery_bank` valid/ready event with off/token/note/preset,
plus ordinary/selective sustain, release step, glide index, lead attack index
and a registered Q16 bend factor. Output is signed 16-bit mono PCM with `out_valid`,
`clipped` and sticky `deadline_missed`. The board top sends the same PCM to
PT8211 left and right. There is no display/communication CDC in this candidate;
the C integration needs a separate stable sample/status interface and whole
design implementation. Pins follow this candidate's CST and must be reconciled
with C's HDMI map during integration.
