"""Independent offline algorithm auditions. These are NOT synthesized FPGA RTL.

Uses NumPy; same score and one fixed amplitude coefficient for all notes.
No third-party implementation copied; see README for upstream study links.
"""
from pathlib import Path
import wave,json
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
FS=50_000_000/1040
OUT=ROOT/'evidence/audio'
def freq(note):return 440*2**((note-69)/12)
def fm(note,velocity,length,seed):
    t=np.arange(length)/FS
    attack=1-np.exp(-t/.006)
    carrier=attack*np.exp(-t/1.15)
    index=(1.2+1.8*velocity)*np.exp(-t/.16)
    return .13*velocity*carrier*np.sin(2*np.pi*freq(note)*t+index*np.sin(2*np.pi*freq(note)*t))
def pluck(note,velocity,length,seed):
    # Fractional interpolated delay plus a two-tap averaging loop filter.
    # Half-sample loop-filter delay is subtracted in pitch setup.
    delay=FS/freq(note)-.5;integer=int(delay);fraction=delay-integer
    rng=np.random.default_rng(seed)
    ring=rng.uniform(-1,1,integer+2);ring-=ring.mean()
    y=np.zeros(length);pointer=0;previous=0
    for i in range(length):
        a=ring[(pointer-integer)%len(ring)]
        b=ring[(pointer-integer-1)%len(ring)]
        value=(1-fraction)*a+fraction*b
        ring[pointer]=.997*(value+previous)*.5
        previous=value;pointer=(pointer+1)%len(ring)
        y[i]=.24*velocity*value
    return y
def render(fun):
    score=[([48],.8),([55],.8),([60],.8),([64],.8),([67],.8),([72],.8),([60,64,67],.6),([60],.25),([60],.5),([60],.9)]
    slot=round(FS*.75);gate=round(FS*.53);release=round(FS*.15)
    result=np.zeros(slot*len(score))
    for j,(notes,velocity) in enumerate(score):
        for note in notes:
            y=fun(note,velocity,gate+release,2000+note+j)
            y[gate:]*=np.linspace(1,0,release)
            result[j*slot:j*slot+len(y)]+=y
    assert np.max(np.abs(result))<1
    return result
def write(name,y):
    values=np.rint(y*32767).astype('<i2')
    with wave.open(str(OUT/name),'wb') as w:w.setparams((1,2,48077,0,'NONE','not compressed'));w.writeframes(values.tobytes())
    return {'file':name,'samples':len(values),'peak':int(np.max(np.abs(values.astype(int)))),'rms':float(np.sqrt(np.mean(values.astype(float)**2)))}
OUT.mkdir(parents=True,exist_ok=True)
records=[write('candidate_fm_offline.wav',render(fm)),write('candidate_pluck_offline.wav',render(pluck))]
print(json.dumps(records,indent=2))
