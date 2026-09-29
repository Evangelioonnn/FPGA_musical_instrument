"""Analyze digital RTL output and export fixed-gain auditions; requires NumPy."""
from pathlib import Path
import json,wave,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
SIM=ROOT/'project/system/sim';OUT=ROOT/'evidence/audio'
FS=50_000_000/1040
REPORT=ROOT/'evidence/system_v0_2026-09-19';REPORT.mkdir(exist_ok=True)
def load(name):return np.loadtxt(SIM/name,dtype=np.int64)
def save(name,y,gain=1):
    out=y*gain
    assert out.min()>=-32768 and out.max()<=32767, (name,int(out.min()),int(out.max()))
    with wave.open(str(OUT/name),'wb') as w:
        w.setparams((1,2,48077,0,'NONE','not compressed'));w.writeframes(out.astype('<i2').tobytes())
    return {'samples':len(y),'gain':gain,'raw_min':int(y.min()),'raw_max':int(y.max()),'sha256':hashlib.sha256((OUT/name).read_bytes()).hexdigest()}
def frequency(y):
    y=y-y.mean();window=np.hanning(len(y));a=np.abs(np.fft.rfft(y*window))
    k=int(np.argmax(a[1:])+1);logs=np.log(a[k-1:k+2]+1e-12)
    delta=.5*(logs[0]-logs[2])/(logs[0]-2*logs[1]+logs[2])
    return (k+delta)*FS/len(y)
result={'fs_actual':FS,'wav_fs_rounded':48077,'source':'RTL simulation, not analog recording','audio':{}}
y=load('system_samples.txt')
assert len(y)==16*48077
with wave.open(str(OUT/'baseline_raw.wav'),'rb') as w:
    reference=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,w.getnchannels())[:,0]
assert np.array_equal(y,reference),'default differs from published reference'
result['default_reference_sample_equal']=len(y)
for note,expected in [('c4',261.625565),('a4',440.0)]:
    samples=load('lab_'+note+'_samples.txt');assert len(samples)==10*48077
    f=frequency(samples[2*48077:6*48077])
    assert abs(f-expected)<.02 and not np.any(samples[:48077]) and not np.any(samples[8*48077:])
    result['audio']['lab_'+note+'_raw.wav']=save('lab_'+note+'_raw.wav',samples)
    result['audio']['lab_'+note+'_preview.wav']=save('lab_'+note+'_preview.wav',samples,8)
    result['lab_'+note+'_frequency_hz']=f
input_samples=load('input_samples.txt');assert len(input_samples)==6*48077
result['audio']['input_sequence_preview.wav']=save('input_sequence_preview.wav',input_samples,8)
delay=np.loadtxt(ROOT/'project/experiments/delay/sim/delay_samples.txt',dtype=np.int64)
assert len(delay)==len(y)+96000
# Independent history implementation verifies every rendered sample, including tail.
history=[];wet=0;peak=0
def trunc(x):return x//32768 if x>=0 else -((-x)//32768)
for i,x in enumerate(np.pad(y,(0,96000))):
    x=int(x);wet=min(16384,wet+256);old=history[-4096] if len(history)>=4096 else 0
    expected=max(-32768,min(32767,x+trunc(old*wet)))
    assert delay[i]==expected, ('delay output mismatch',i)
    history.append(max(-32768,min(32767,x+trunc(old*24576))))
result['delay_render_checked_samples']=len(delay)
result['audio']['delay_preview.wav']=save('delay_preview.wav',delay,4)
for n in (16,32):
    signal=load(f'capacity{n}_samples.txt')[1000:21000]
    window=np.hanning(len(signal));bins=np.fft.rfftfreq(len(signal),1/FS)
    spectrum=np.abs(np.fft.rfft(signal*window))*2/window.sum()
    peaks=[]
    for note in range(48,48+n):
        expected=440*2**((note-69)/12)
        search=np.flatnonzero(np.abs(bins-expected)<FS/len(signal)*1.5)
        k=search[np.argmax(spectrum[search])]
        assert spectrum[k]>100,(n,note,'weak/missing fundamental')
        peaks.append({'note':note,'expected_hz':expected,'bin_hz':float(bins[k]),'amplitude':float(spectrum[k])})
    result[f'capacity{n}_fundamentals']=peaks
(REPORT/'audio_analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('AUDIO_ANALYSIS_PASS default_equal=769232 lab_frequencies/silence=pass capacity_fundamentals=16/32 delay_oracle='+str(len(delay)))
