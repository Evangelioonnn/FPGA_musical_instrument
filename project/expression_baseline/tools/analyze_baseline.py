"""Validate real-duration RTL samples; use one fixed gain for all preview audio."""
from pathlib import Path
import json
import math
import struct
import wave

root = Path(__file__).resolve().parents[1]
samples = [int(v) for v in (root / 'sim/baseline_samples.txt').read_text().split()]
rate, slot = 50_000_000 / 1040, 48077
assert len(samples) == 16 * slot
assert max(samples) <= 4096 and min(samples) >= -4096
original_path = root.parent / 'instrument/sim/demo_samples.txt'
original_compared = 0
if original_path.exists():
    original = [int(v) for v in original_path.read_text().split()][:2*slot]
    assert len(original) == 2*slot
    assert samples[:2*slot] == original, 'Initial C4 differs from original instrument render'
    original_compared = 2*slot

def section(start, end):
    return samples[round(start * slot):round(end * slot)]

def rms(values):
    return math.sqrt(sum(v * v for v in values) / len(values))

for start, end in [(0, 1), (2, 3), (3.52, 3.69), (4.15, 5), (7.93, 8), (9.15, 10),
                   (11.15, 12), (13.15, 14), (15.15, 16)]:
    assert all(v == 0 for v in section(start, end)), ('silence', start, end)

base = section(1, 2)
crossings = [i for i in range(12001, 29000) if base[i-1] < 0 <= base[i]]
hz = (len(crossings)-1) * rate / (crossings[-1]-crossings[0])
assert abs(hz / (440 * 2**(-9/12)) - 1) < 0.001
base_sustain = rms(section(1.3, 1.6))
assert 179 < base_sustain < 183, base_sustain  # original +/-256 sustain
velocity_rms = [rms(section(s+.3, s+.6)) for s in (5, 6, 7)]
assert abs(velocity_rms[1] / velocity_rms[0] - 2) < .03
assert abs(velocity_rms[2] / velocity_rms[1] - 2) < .03
volume_rms = [rms(section(a,b)) for a,b in [(3.15,3.28),(3.35,3.48),(3.75,3.85)]]
assert abs(volume_rms[1] / volume_rms[0] - .25) < .01
assert abs(volume_rms[2] / volume_rms[0] - 1) < .02
assert rms(section(8.7,8.8)) > 100
assert rms(section(10.3,10.38)) > 100
assert rms(section(14.3,14.6)) > base_sustain

report = dict(source='RTL simulation; not a board recording', samples=len(samples),
              sample_rate_hz=rate, minimum=min(samples), maximum=max(samples),
              reference_c4_hz=hz, reference_sustain_rms=base_sustain,
              velocity_rms=velocity_rms, volume_rms=volume_rms,
              preview_gain=8, note_events=48, simultaneous_voices=8,
              original_instrument_samples_compared=original_compared)
(root / 'sim/audio_analysis.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')

def write_wav(name, values, gain):
    out = [v * gain for v in values]
    assert all(-32768 <= v <= 32767 for v in out), name
    with wave.open(str(root / 'sim' / name), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(round(rate))
        wav.writeframes(struct.pack('<'+'h'*len(out), *out))

write_wav('baseline_raw.wav', samples, 1)
write_wav('baseline_preview.wav', samples, 8)
print('BASELINE_AUDIO_ANALYSIS_PASS ' + json.dumps(report))
