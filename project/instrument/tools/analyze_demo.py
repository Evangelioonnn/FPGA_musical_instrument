"""Analyze RTL-generated samples. Standard library only; no audio dependencies."""
from pathlib import Path
import math
import json
import struct
import wave

root = Path(__file__).resolve().parents[1]
samples = [int(v) for v in (root/'sim/demo_samples.txt').read_text().split()]
fs = 50_000_000/1040
slot = 48077
assert len(samples) == 6*slot, len(samples)
assert min(samples) >= -512 and max(samples) <= 511
assert all(x == 0 for x in samples[:slot])
assert all(x == 0 for x in samples[5*slot:])

def rms(values):
    return math.sqrt(sum(x*x for x in values)/len(values))

results = []
for index, note in enumerate([60,64,67,72], 1):
    x = samples[index*slot:(index+1)*slot]
    crossings = [i for i in range(10001,29000) if x[i-1]<0<=x[i]]
    hz = (len(crossings)-1)*fs/(crossings[-1]-crossings[0])
    target = 440*2**((note-69)/12)
    assert abs(hz/target-1)<0.001, (note,hz,target)
    early = rms(x[0:250])
    peak = rms(x[900:1200])
    sustain = rms(x[12000:24000])
    release = rms(x[35000:37000])
    assert 0 < early < peak and 0 < release < sustain < peak
    assert all(v==0 for v in x[44000:]), (note,'release did not end')
    results.append(dict(note=note,target_hz=target,measured_hz=hz,
                        early_rms=early,peak_rms=peak,sustain_rms=sustain,release_rms=release))
report = dict(source='RTL simulation, not board recording', sample_rate_hz=fs,
              samples=len(samples),minimum=min(samples),maximum=max(samples),notes=results)
(root/'sim/audio_analysis.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
with wave.open(str(root/'sim/demo_simulated.wav'),'wb') as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(round(fs))
    wav.writeframes(struct.pack('<'+'h'*len(samples),*samples))
print('AUDIO_ANALYSIS_PASS: four pitches, ADSR shape, silence, amplitude; simulated WAV saved')
for row in results:
    print(f"note={row['note']} measured_hz={row['measured_hz']:.6f}")
