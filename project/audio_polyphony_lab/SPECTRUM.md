# 32 distinct fundamental frequencies: focused digital evidence

2026-09-28. `poly_spectrum_tb` and `tools/run_spectrum.py` passed.
This test is **logical input injection**, not a physical32-key board test.
Existing HDL/Gowin project inputs, PnR records, original regression results and
three preview WAVs are unchanged by this extra test.

## Method and result

- All32 voices start before the first audio frame, with distinct strike tokens
 1..32 and MIDI notes48..79. Every retained note has a different frequency step.
- Accepted piano defaults68/6/32768/3 are retained. After7000 warmup frames,
  all32 envelopes are nonzero and in sustained state, with held/gated/occupied
  masks equal to0xffffffff. The bench checks every voice, token and step.
- Actual RTL PCM is captured for32768 frames. Peak4107, no output clipping,
  no deadline fault; calculation finishes at514 clocks/frame.
- The32 safe mode uses the documented fixed1/4 per-voice gain. There is no gain
  change based on active count, offline normalisation or PCM playback.
- The FFT uses exact board Fs50000000/1040 =48076.923076923Hz, a symmetric Hann
  window, DC removal and coherent-gain amplitude correction. Resolution is
  1.467191Hz and the observed duration is0.6815744s.
- ModelSim uses a separate `work_spectrum` library and520 clocks/frame to omit
  idle clocks. The same reusable renderer completes before520. Prior evidence
  compares403 normal1040-cycle and accelerated520-cycle PCM samples exactly;
  acceleration changes simulation duration, not the logical output sequence
  interpreted at the board's actual audio rate.
- Every target has a distinct local FFT maximum within one bin of its actual
  phase-step frequency. All32 pass the20dB prominence threshold.

The reference floor is the median FFT amplitude80..3500Hz after excluding
three bins on each side of all four harmonics of every target. Reported
prominence is approximately91.5..94.8dB over this digital reference floor.
**It is not an analogue SNR/SINAD measurement or a claim that board noise is fixed.**

## All32 targets

Rounded displayed values; full phase-step frequencies, peak bins, amplitudes,
prominence and pass flags are in [results/spectrum32.json](results/spectrum32.json).

| MIDI | Target Hz | Interpolated peak Hz | Result |
|---:|---:|---:|---|
| 48 | 130.813 | 130.829 | Pass |
| 49 | 138.591 | 138.601 | Pass |
| 50 | 146.832 | 146.843 | Pass |
| 51 | 155.563 | 155.566 | Pass |
| 52 | 164.814 | 164.837 | Pass |
| 53 | 174.614 | 174.615 | Pass |
| 54 | 184.997 | 185.008 | Pass |
| 55 | 195.998 | 195.981 | Pass |
| 56 | 207.652 | 207.646 | Pass |
| 57 | 220.000 | 219.993 | Pass |
| 58 | 233.082 | 233.066 | Pass |
| 59 | 246.942 | 246.965 | Pass |
| 60 | 261.626 | 261.649 | Pass |
| 61 | 277.183 | 277.173 | Pass |
| 62 | 293.665 | 293.682 | Pass |
| 63 | 311.127 | 311.134 | Pass |
| 64 | 329.628 | 329.605 | Pass |
| 65 | 349.228 | 349.231 | Pass |
| 66 | 369.994 | 370.013 | Pass |
| 67 | 391.995 | 392.027 | Pass |
| 68 | 415.305 | 415.323 | Pass |
| 69 | 440.000 | 439.995 | Pass |
| 70 | 466.164 | 466.144 | Pass |
| 71 | 493.883 | 493.862 | Pass |
| 72 | 523.251 | 523.223 | Pass |
| 73 | 554.365 | 554.333 | Pass |
| 74 | 587.330 | 587.332 | Pass |
| 75 | 622.254 | 622.235 | Pass |
| 76 | 659.255 | 659.240 | Pass |
| 77 | 698.456 | 698.410 | Pass |
| 78 | 739.989 | 739.955 | Pass |
| 79 | 783.991 | 783.949 | Pass |

Some higher target frequencies coincide with harmonics of lower notes. The
spectrum alone therefore does not prove32 independent oscillators. The full
evidence combines distinct token/frequency/phase/envelope state in RTL,
independent numerical and identity tests, and32 distinct audible fundamental
peaks. These states are32 piano voices; the four harmonics inside a voice do not
increase that voice count.

## Reproduce and evidence boundary

Run using an existing Python environment with NumPy (tested NumPy2.3.5), then:

```powershell
python project/audio_polyphony_lab/tools/run_spectrum.py
```

`--modelsim` can override the ModelSim executable directory. No installation,
network request, broad regression, PnR rerun or original preview regeneration
is needed. The run hashes all HDL/bench/analysis sources before and after the
simulation. New ignored products are `sim/poly_spectrum32_pcm.txt`,
`sim/poly_spectrum32_voices.txt`, `sim/poly_spectrum32.log` and `work_spectrum`.
The compact JSON records source/PCM/snapshot SHA256, exact Fs, window,
resolution, all32 detections and `board_tested=false`.

Pending: real board arbitrary32-key injection or equivalent hardware event
source, physical sound/FFT evidence, analogue noise and latency measurement,
and fresh final combined-system PnR. This digital supplement does not close
those hardware acceptance items.
