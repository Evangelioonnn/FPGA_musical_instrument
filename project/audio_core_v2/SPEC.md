# Audio core V2 candidate contract

Owner A; baseline `615cb94`; task branch `codex/audio-core-v2`.
This is a new candidate. Accepted V1 and independent piano16/32 remain intact.
Implementation, simulation, physical PnR and board acceptance are separate gates.

## Voice allocation

Stable menu: `0 -> 2 -> 3 -> 4 -> 5 -> 0`. IDs are not renumbered.
There are 32 global logical slots, independent strike tokens and note-offs.
Piano 0, bell 3, Drive lead 4 and custom 5 share 32 harmonic states and one
renderer. Warm pluck 2 has a separate 12-slot physical pool. The 16-slot
candidate exceeded BSRAM/full-interface Logic budgets and was not selected.
Mixed timbres and their tails together may occupy at most 32 logical slots.
An exhausted pool rejects a new strike and increments a count; it never steals
an old voice, reuses its token, or silently changes its timbre.

Each harmonic voice has independent phase, pitch/glide and envelope state.
Four harmonics within one voice share phase and envelope. They are not four
independent oscillators. Warm pluck retains the accepted delay-line algorithm,
warm filter and natural decay. Pedals and ADSR do not force pluck to sustain.
Changing the selected timbre affects new strikes; existing tails keep their ID.

## Arithmetic and sound

The accepted raw signed Q4 voice samples are preserved. Harmonic presets use
fixed 1/4 per-note gain relative to V1; Warm pluck keeps V1 gain.
The signed accumulator weights harmonic samples by 1 and pluck samples by 4,
then rounds symmetrically by 64. This is not active-count normalisation.
Do not claim unchanged piano single-note loudness or 32 notes at V1 full gain.
The final master volume and optional room effect remain downstream.
Overflow saturates with an explicit clip diagnostic; tests must establish the
headroom of allowed parameters, not merely hide clipping behind master mute.

Custom coefficients are unsigned Q8, 256 = 1.0. Default `[256,64,32,16]`
preserves the accepted piano shape. Sum above 368 is proportionally limited;
four full faders become `[92,92,92,92]`. Coefficients slew at PCM boundaries
and each rendered frame captures a coherent set. Master CH0 is independent
post-mix Q16, 0..65536. Physical SPI ADC is still absent.

## Scheduling and interfaces

All audio logic uses 50 MHz, one `sample_ce` every 1040 clocks:
Fs = 48076.9230769 Hz. A shared pipelined 32x17 pitch multiplier services
states sequentially, followed by the shared tone renderer and serial mixer.
The complete chain must finish before the next PCM boundary, under full load.
Digital deadline is a sticky fault. Exact measured clocks belong in VALIDATION.

Physical matrix/EC11/three user keys and PT8211 wiring start unchanged.
The physical 16-key matrix is a test adapter, not the logical voice limit or
the future 25-key two-zone PCB. Undioded matrix ghost protection remains.
Host and simulated ADC use the accepted parameter-service handshake.
PCM has no observation backpressure; C must not stall synthesis or note-offs.

State storage is one 301bit x32 synchronous RAM. The renderer consumes one
voice at a time; pluck mean/interpolation/feedback/release share one 34x26
multiplier. Envelope calculation has a pipeline register before tone amplitude
multiplication. Extended snapshots and static capabilities follow
docs/interfaces/AUDIO_CORE_V2.md; C must not decode V2 using a fixed V1 N8 size.

## Resource and product boundaries

Hard A+input caps: 29000 Logic, 17000 Register, 70 BSRAM, 78 DSP.
C keeps 13000 Logic, 10000 Register, 26 BSRAM, 16 DSP and one PLL.
Current physical input adapters and room effect are included in A figures.
Future physical input headroom and full-interface retained logic must be audited.
A separate audio PnR is not audio+display+Bluetooth whole-system PnR.
Bank5/Y12 electrical integration, SPI ADC, control PCB and analogue latency
remain outside this isolated build. No claim of analogue noise root-cause repair.
