"""Independent frequency/mixture/continuity checks of RTL samples; stdlib only."""
from pathlib import Path
import array
import json
import math
import wave

ROOT=Path(__file__).resolve().parents[1]
FS=50_000_000/1040
SLOT=48077
NOTES=(60,64,67,72)
FREQS=[440*2**((n-69)/12) for n in NOTES]

def solve(matrix,vector):
    rows=[row[:]+[value] for row,value in zip(matrix,vector)]
    n=len(rows)
    for i in range(n):
        pivot=max(range(i,n),key=lambda k:abs(rows[k][i]))
        rows[i],rows[pivot]=rows[pivot],rows[i]
        assert abs(rows[i][i])>1e-9
        divisor=rows[i][i]
        rows[i]=[x/divisor for x in rows[i]]
        for j in range(n):
            if j!=i:
                scale=rows[j][i]
                rows[j]=[x-scale*y for x,y in zip(rows[j],rows[i])]
    return [row[-1] for row in rows]

def fit(values,start,frequencies):
    size=2*len(frequencies)+1
    gram=[[0.0]*size for _ in range(size)]
    rhs=[0.0]*size
    for i,y in enumerate(values):
        t=(start+i)/FS
        basis=[]
        for f in frequencies:
            angle=2*math.pi*f*t
            basis.extend((math.sin(angle),math.cos(angle)))
        basis.append(1.0)
        for j,a in enumerate(basis):
            rhs[j]+=a*y
            for k in range(j,size): gram[j][k]+=a*basis[k]
    for j in range(size):
        for k in range(j):gram[j][k]=gram[k][j]
    coeff=solve(gram,rhs)
    amplitudes=[math.hypot(coeff[2*i],coeff[2*i+1]) for i in range(len(frequencies))]
    return amplitudes,coeff

rows=[tuple(map(int,line.split())) for line in (ROOT/'sim/poly_samples.txt').read_text().splitlines()]
assert len(rows)==8*SLOT and all(len(row)==5 for row in rows)
assert all(row[0]==sum(row[1:])//4 for row in rows), 'Mixture mismatch'
assert all(-512<=row[0]<=511 for row in rows)
assert all(row==(0,0,0,0,0) for row in rows[:SLOT]+rows[7*SLOT:])
assert all(row[2]==0 for row in rows[5*SLOT+12000:]),'E4 stuck after release'

individual=[]
start=4*SLOT+12000
for voice,(note,freq) in enumerate(zip(NOTES,FREQS),1):
    samples=[row[voice] for row in rows[start:start+17000]]
    crossings=[]
    for i in range(1,len(samples)):
        if samples[i-1]<0<=samples[i]:
            crossings.append(i-1-samples[i-1]/(samples[i]-samples[i-1]))
    assert len(crossings)>50
    measured=(len(crossings)-1)*FS/(crossings[-1]-crossings[0])
    assert abs(measured/freq-1)<0.001,(note,measured,freq)
    individual.append(dict(note=note,target_hz=freq,measured_hz=measured))

stages=[]
for slot,active in ((1,(0,)),(2,(0,1)),(3,(0,1,2)),(4,(0,1,2,3)),(5,(0,2,3))):
    begin=slot*SLOT+12000
    amplitudes,_=fit([row[0] for row in rows[begin:begin+17000]],begin,FREQS)
    for voice,amplitude in enumerate(amplitudes):
        if voice in active: assert abs(amplitude-64)<1.0,(slot,voice,amplitude)
        else: assert amplitude<0.2,(slot,'unexpected note',voice,amplitude)
    stages.append(dict(slot=slot,active_notes=[NOTES[i] for i in active],fitted_peak_codes=amplitudes))

continuity=[]
for voice in (0,2,3):
    freq=FREQS[voice]
    _,coeff=fit([row[voice+1] for row in rows[start:start+17000]],start,[freq])
    after=5*SLOT+12000
    errors=[]
    for i,row in enumerate(rows[after:after+17000]):
        angle=2*math.pi*freq*(after+i)/FS
        prediction=coeff[0]*math.sin(angle)+coeff[1]*math.cos(angle)+coeff[2]
        errors.append(abs(row[voice+1]-prediction))
    assert max(errors)<3,(NOTES[voice],'phase/envelope interruption',max(errors))
    continuity.append(dict(note=NOTES[voice],max_prediction_error_codes=max(errors)))

mix=[row[0] for row in rows]
with wave.open(str(ROOT/'sim/polyphony_simulated.wav'),'wb') as wav:
    wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(round(FS))
    wav.writeframes(array.array('h',mix).tobytes())
report=dict(source='RTL simulation; not board recording',samples=len(rows),sample_rate_hz=FS,
            minimum=min(mix),maximum=max(mix),individual_frequencies=individual,
            mixture_stages=stages,unreleased_voice_continuity=continuity)
(ROOT/'sim/poly_analysis.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('POLY_ANALYSIS_PASS samples={} range={}..{}'.format(len(rows),min(mix),max(mix)))
for row in individual:print('note={} measured={:.6f}Hz'.format(row['note'],row['measured_hz']))
for row in stages:print('slot={} active={} peaks={}'.format(row['slot'],row['active_notes'],[round(v,3) for v in row['fitted_peak_codes']]))
