# Interface and numerical contract

## short_room_reverb

All ports are in the50MHz domain with synchronous active-high reset.

| Port | Meaning |
|---|---|
| `in_valid` | One-clock pulse carrying one signed16 PCM sample |
| `in_sample` | Full signed16 range, -32768..32767 |
| `fx_enable` | Effect target; sampled with accepted input |
| `wet_q8[8:0]` | Wet ratio in Q8; 256=100%; saturates at128=50% |
| `out_valid` | One-clock pulse exactly24 clocks after accepted input |
| `out_left/right` | Actual stereo effect output; hold between valid pulses |
| `clip` | Frame-aligned saturation flag; proven unreachable for legal input/control |
| `ready` | Delay RAM has been fully cleared; before then audio passes dry |
| `busy` | Transaction active; legal input frames never encounter it |
| `overrun` | Sticky invalid-input-rate flag; clears with reset |
| `wet_applied` | Current applied ratio after clamp and smoothing |

Input spacing must be at least25 clocks; normal audio spacing is1040.
There is no downstream backpressure. An unexpected input while busy is rejected
and sets `overrun`; the caller must not interpret that input as rendered audio.
Controls are one coherent snapshot at input acceptance. A ratio change moves
by at most1 Q8 unit per accepted frame:0..128 takes128 frames, about2.66ms.

Reset starts a4096-clock RAM write sweep (81.92us at50MHz). No array-wide
reset is used. Before `ready`, accepted samples retain the same24-clock latency,
produce exact dry stereo, and never read uncleared RAM into an output. A warmup
frame remains dry even if `ready` asserts partway through its transaction.

When disabled from reset, `wet_applied=0` and both outputs equal the input
bit-for-bit. Disabling an active effect ramps to zero; bit-exact dry starts once
the applied ratio reaches zero. Delay state continues tracking the input while
bypassed, allowing smooth activation without an unrelated old frozen tail.

## Delay network and amplitude bounds

Four independent feedback combs share a4096x16 synchronous RAM. Lengths are
601,733,887,1091 frames (12.50,15.25,18.45,22.69ms at the actual Fs).
Each ring returns its previous sample `d_i[n]`, then writes

```
b_i[n] = trunc_toward_zero(x[n]/4) + trunc_toward_zero(3*d_i[n]/4)
```

Feedback magnitude is0.75, equivalent to roughly0.30..0.54s RT60 in each
isolated loop before integer quantization. This is a small room candidate,
not a dense studio reverberator. Stereo wet paths use different positive weights:

```
wL = trunc_toward_zero((3*d0 + 2*d1 + d2 + 2*d3)/8)
wR = trunc_toward_zero((d0 + 2*d1 + 3*d2 + 2*d3)/8)
yL/R = x + trunc_toward_zero((wL/R-x)*wet_applied/256)
```

The weighted sums use20 signed bits; shared wet multiplication uses signed18x10
with28-bit product. Saturation is a last guard and an observable fault, not
routine normalization. No active-voice count or limiter changes dry gain.

For any input in[-32768,32767], induction gives the same bound for every delay
cell: minimum is-8192-24576=-32768; positive maximum is8191+24575=32766.
Each wet output is a convex weighted combination and remains in that interval.
For any wet in[0,128], each output lies between the dry and wet endpoints
(truncation can move it by less than one count toward dry). Thus valid arithmetic
does not clip even for permanent full-scale DC. With zero input, every nonzero
delay cell shrinks in magnitude on its next visit, so no DC quantization limit
cycle can persist. This recurrence uses truncation toward zero deliberately.

The RAM uses one read/write schedule and one variable multiplier reused for L/R.
Four comb iterations take16 clocks; stereo and wet mixing complete at clock24.
Default ratio is0; suggested first audible ratio is64 (25% wet).

Integrate before the final master-volume operation, or provide a final stereo
master-volume stage. Feeding already-scaled PCM means a previously stored room
tail survives an immediate source-volume mute, which is not a full master mute.

## vibrato_factor

Ports: `clk,rst,sample_ce,enable,depth[7:0],speed_index[2:0]`, outputs
`factor_q16[16:0]`, `depth_applied[6:0]`. Parameters update only at `sample_ce`.
Output is an unsigned frequency multiplier with unity65536; it is not a note
number and must be applied to the DDS frequency increment with sufficient width.
The receiving pipeline normally uses the value stable from the previous frame.

Depth saturates at64 and changes by at most1 per sample. A24-bit phase accumulator
feeds a triangle from-128..127. Target factor is
`65536 + floor(triangle*depth_applied/4)`, limited to16 Q16 counts of movement
per frame. Maximum range is63488..67568 (about-54.96..+52.86 cents); off returns
to exactly65536 smoothly after depth decays. No oscillator reset is induced.

| Speed index | Increment | Actual Hz at Fs=50MHz/1040 |
|---|---:|---:|
| 0 | 698 | 2.000 |
| 1 | 1047 | 3.000 |
| 2 | 1396 | 4.000 |
| 3 | 1745 | 5.000 |
| 4 | 2094 | 6.001 |
| 5 | 2443 | 7.001 |
| 6 | 2792 | 8.001 |
| 7 | 3141 | 9.001 |

The LFO runs while disabled, so enable does not create a discontinuous phase
reset. Triangle vibrato is an explicit controllable musical modulation; it must
not be confused with previously reported unwanted beating/noise. One shared
factor can modulate all Lead voices; per-key independent vibrato would require
separate modulation state and additional resource accounting.
