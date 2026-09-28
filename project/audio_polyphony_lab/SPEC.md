# Core and arithmetic contract

## Reusable core

`src/piano_poly_core.v`, module `piano_poly_core #(N, OUTPUT_SHIFT)`.
One 50MHz clock domain, synchronous active-high reset. Fs is externally supplied
by `sample_ce` once every 1040 cycles. Supported tested capacities are 8/16/32.

| Signal | Meaning |
|---|---|
| `event_valid / event_ready` | One event is captured on the rising clock edge when both are high. Producer retains payload while stalled. |
| `event_off` | 0 starts a distinct voice, 1 releases the matching strike. |
| `event_token[31:0]` | Nonzero strike identity. Equal pitches with different identities remain separate voices. |
| `event_note[6:0]` | MIDI36..84 on note-on. Off matches token; its note is ignored. |
| `attack_step / decay_step[15:0]` | Envelope Q16 code increment/decrement per sample; zero acts as one. Snapshotted on note-on. |
| `sustain_level[15:0]` | ADSR sustain amplitude code0..65535, snapshotted on note-on. |
| `release_step[15:0]` | Envelope decrement per sample, zero acts as one. Snapshotted when release begins. |
| `sustain / sostenuto` | Ordinary pedal / selective pedal. Selective rising edge captures occupied held voices before same-edge events. |
| `accepted / rejected` | One-clock completion indication after serial identity/allocation processing, not necessarily the capture edge. |
| `rejected_count` | Full bank, duplicate/zero identity or invalid note counter. No voice stealing. |
| `unmatched_off_count` | Off with zero or unknown token; safely ignored. |
| `occupied / held / gated[N-1:0]` | Voice exists / physical key held / envelope has not entered release. |
| `mixed_q4 signed[31:0]` | Real pre-DAC sum with four fractional bits, unaffected by OUTPUT_SHIFT. Valid with out_valid. |
| `out_sample signed[15:0] / out_valid` | Rounded, fixed-gain, saturated mono PCM. |
| `clipped` | One-clock saturation indication for the valid sample. |
| `deadline_missed` | Sticky renderer deadline error; reset clears. |

ADSR defaults are68/6/32768/3. A fresh voice starts phase0/envelope0.
The first audio frame advances phase by its independent note step and envelope
by68. The original retrigger policy is represented by creating a new identity
and independent envelope, rather than merging same-pitch voices.

Parameter changes do not alter already snapshotted attack, decay or sustain.
Changing the global release step affects voices that enter release afterwards.
This preserves prior release semantics. External adapters can define preset
updates without reusing a voice's strike identity.

Events are scanned one slot per clock. If an audio frame starts mid-scan, the
scan is restarted after rendering so allocation uses current voice state.
At full capacity a new note is rejected; releasing an old note always searches
its identity and is not dropped because the bank is full. A source must inspect
rejection status, and preserve note-off priority in its upstream queue.
An event that misses a frame is applied for the next frame. The maximum audio
pipeline latency is130/258/514 clocks for8/16/32 voices, respectively, all within
1040. This is arithmetic latency, not measured key-to-analogue latency.

Voice state masks change during the serial scan. Snapshot them at out_valid for
a coherent completed-frame view. A separate pixel/communication clock requires
proper CDC or snapshots; this core does not supply an asynchronous interface.

## Shared calculation and exact sound equation

For phaseP and envelopeE, signed ROM values are:

```
A = sine(P[31:20])
B = sine((2*P mod 2^32)[31:20])
C = sine((3*P mod 2^32)[31:20])
D = sine((4*P mod 2^32)[31:20])
shape = 128*A + 32*B + 16*C + 8*D
voice_q4 = symmetric_round(shape*E / 2^23)
mix_q4 = sum(voice_q4)
PCM = saturate16(symmetric_round(mix_q4 / 2^(4+OUTPUT_SHIFT)))
```

Sine reads occur sequentially through one synchronous4096x16 table.
The weights are shifts; one amplitude multiplier services every envelope.
Each voice uses16 clocks for state update and rendering. `out_valid` appears
16*N+2 clocks after sample_ce. Allocation runs in spare clocks between frames.
There is no gain division by the number of active voices.

## Headroom is an explicit mode property

ROM extrema are +/-32767. Triangle-inequality bound:
`abs(shape) <= 32767*184 = 6029128`.
After envelope and symmetric rounding, `abs(voice_q4) <= 47102`.
A32-voice sum is bounded by1507264, safely inside signed32 bits.

| Capacity | OUTPUT_SHIFT | Guaranteed output bound | Per-voice gain relative to old eight-voice core |
|---|---:|---:|---:|
| 8 | 0 | 23551 | 1 |
| 16 | 1 | 23551 | 1/2 (-6.02dB) |
| 32 | 2 | 23551 | 1/4 (-12.04dB) |

The fixed gain is applied after mixing, so harmonic calculation and envelopes
remain exactly the accepted piano. Already sounding notes are not reduced when
another note starts. Single notes in high-poly safe modes are quieter by the
documented fixed factor; this must be disclosed during audition.

Full-level OUTPUT_SHIFT0 exposes the original per-voice gain. Full-capacity
same-note tests actually clip at16/32, so it cannot promise zero distortion.
The full-precision mixed_q4 output allows later product integration to adopt a
different explicit gain policy. No limiter or dynamic compression is hidden.

Ordinary/sostenuto hold key-released voices before release. Removing both hold
sources starts release. A selected tail is not retroactively captured once its
physical key has already been released. Finished voices free their slot.

## Integration boundary

This is an independent piano-only board experiment. It does not add32 voices
to the existing eight-voice five-timbre candidate automatically. A combined
mode needs transition/old-tail policy, resource and50MHz timing verification.
Every voice has independent phase, frequency and envelope; the four harmonics
inside one voice are not four independently controlled oscillators.
