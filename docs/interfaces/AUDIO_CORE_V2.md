# Audio interface V2 candidate

Producer: `project/audio_core_v2/src/audio_v2_core.v`. Owner A.
V1 is preserved at `project/audio_core_v1`; this is a new version, not an
undocumented replacement of SYSTEM_V0 or V1. Current validation and final
capacity belong in the V2 VALIDATION document. This contract does not claim
physical ADC, Bluetooth or video integration.

## Common transport

Clock, reset, coherent keys, host requests/ACK, simulated ADC, PCM, index and
parameter units follow [V1](AUDIO_CORE_V1.md). They remain in the 50 MHz domain.
Fs = 50 MHz / 1040. There is no PCM or snapshot backpressure. C crosses complete
bundles using a handshake or actual asynchronous FIFO and handles sequence gaps.
The board top still uses 16 undioded keys; the core also supports 25 logical
keys (`KEYS=25,SPLIT=12,DIATONIC=0`). Hardware scans and voltage/pins are separate.

Global capacity is 32 logical voice slots. Piano/bell/Lead/custom share this
capacity; Warm pluck has a separately bounded physical pool. Mixed tails count
toward the same 32 limit. A full pool rejects new strikes, never steals an old
one. Stable menu IDs remain 0/2/3/4/5. ID1 is historical and rejected.

The selected build has N32/PLUCK_N12. Core parameters N other than32 are not
qualified by this release. Physical board keys remain16; the retained logical
integration audit uses25 keys. No new electrical allocation is implied.

## Static capabilities

`capabilities[127:0]` is constant for a build. It must travel alongside the
initial state or be explicitly known by C's adapter; it is not UART framing.

| Bits | Meaning |
|---|---|
| 15:0 | Version, 2 |
| 31:16 | Total/harmonic logical capacity N, current 32 |
| 47:32 | Warm pluck physical capacity PLUCK_N; read the final build value |
| 63:48 | Physical/logical key-snapshot width KEYS |
| 71:64 | Supported preset bitmask, 0x3d (IDs 0/2/3/4/5) |
| 79:72 | Harmonic per-note fixed gain shift, 2 (1/4 of V1) |
| 87:80 | Pluck per-note fixed gain shift, 0 (unchanged from V1) |
| 95:88 | Voice record width, 64 |
| 111:96 | Base snapshot width, 320+64*N, current 2368 |
| 127:112 | Base header width, 320 |

This tells C the limits; 32 four-harmonic musical voices are not 128 independent
oscillators. Gain is fixed by timbre, not divided by the current active count.

## Coherent snapshot bundle

On `snapshot_valid`, capture `{snapshot_data,snapshot_extension,snapshot_keys}`
as one bundle. Registers hold their last complete value until the next publish.
The existing `snapshot_data` retains V1's 320-bit header and 64-bit voice record
layout; N32 expands it to 2368 bits. Voice base is `320+64*i`, i=0..31.
The word layout is specified in V1; do not infer active timbre from the selected
menu ID or sound from a pluck's zero envelope field.

`snapshot_keys[KEYS-1:0]` records the actual input key bitmap, including a held
key whose strike was rejected or whose natural voice already ended. Voice
`held` and input `snapshot_keys` have different meanings. `blocked` in the base
header tells the UI about ghost/fault inhibition; it does not erase the physical
key bitmap.

The new `snapshot_extension[255:0]` is captured at the same edge:

| Bits | Meaning |
|---|---|
| 31:0 | PCM sample_index held at snapshot capture |
| 47:32 / 63:48 / 79:64 / 95:80 | Current ADSR A/D/S/R targets, unsigned16 |
| 107:96 / 119:108 / 131:120 / 143:132 | CH1..CH4 raw target ADC codes, unsigned12 |
| 145:144 | Lead attack index |
| 177:146 | Unmatched note-off count, unsigned32 |
| 183:178 | Total capacity N, unsigned6 |
| 189:184 | Pluck pool capacity, unsigned6 |
| 197:190 | Interface version, 2 |
| 205:198 | Harmonic fixed gain shift, 2 |
| 213:206 | Pluck fixed gain shift, 0 |
| 255:214 | Reserved zero |

ADSR targets are not a claim that old voices adopt a new attack/decay/sustain:
those are latched on strike. Effective smooth harmonic coefficients stay in
base bits201:166, while raw fader targets are in this extension. Master target,
applied gain, ownership, sustain and diagnostic reset semantics remain V1.

Snapshot publishes about 46.95 Hz (one per1024 actual PCM publishes). Reset/panic
can create a sequence gap; the extension's PCM index and stream-reset count must
be used rather than multiplying snapshot sequence by1024. Video must latch the
whole state at a frame boundary; UART congestion must not stop audio.

## Integration bounds

A+input hard caps remain 29000 Logic /17000 Reg /70 BSRAM /78 DSP, C retains
13000/10000/26/16 and one PLL. V2 must pass physical-audio PnR and a retained
full-interface synthesis audit. These are not audio+display+Bluetooth whole
system PnR. The Bank5/Y12 issue in DISPLAY.md remains an integration gate.
No SPI ADC pin allocation is frozen here. Analogue latency and noise measurements
still need the real DAC/amplifier chain; RTL reference WAV is not that evidence.

For a resource-conscious C adapter, one coherent handshake and a source-domain
word-copy into RAM can avoid duplicating thousands of payload FFs in every CDC
stage. A 64bit burst needs42 words for the N32 base/extension/KEYS25 state, plus
the static capabilities sent separately. It fits far inside the roughly21.3ms
snapshot interval at50MHz. Freeze/copy a complete record, attach sequence and
length, and cross the record boundary coherently; do not sample live words as
the source updates. This is an implementation suggestion, not a frozen UART
packet or a promise of measured FIFO cost. Slow video/UART may drop older
complete records but must not stall audio or merge words from different ones.
