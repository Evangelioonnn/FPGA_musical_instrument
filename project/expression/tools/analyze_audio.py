"""Check rendered RTL against mathematical frequencies, gains and event semantics."""
from pathlib import Path
from array import array
import math,json,wave,sys
ROOT=Path(__file__).resolve().parents[1]
FS=50_000_000/1040
SLOT=48077
def solve(matrix,vector):
    rows=[r[:]+[v] for r,v in zip(matrix,vector)]
    for i in range(len(rows)):
        p=max(range(i,len(rows)),key=lambda j:abs(rows[j][i]))
        rows[i],rows[p]=rows[p],rows[i]
        div=rows[i][i];assert abs(div)>1e-8
        rows[i]=[v/div for v in rows[i]]
        for j in range(len(rows)):
            if j!=i:
                q=rows[j][i];rows[j]=[a-q*b for a,b in zip(rows[j],rows[i])]
    return [r[-1] for r in rows]
def fit(values,frequencies):
    n=2*len(frequencies)+1
    mat=[[0.0]*n for _ in range(n)];rhs=[0.0]*n
    for i,y in enumerate(values):
        row=[]
        for f in frequencies:
            x=2*math.pi*f*i/FS;row.extend([math.sin(x),math.cos(x)])
        row.append(1.0)
        for j in range(n):
            rhs[j]+=row[j]*y
            for k in range(j,n):mat[j][k]+=row[j]*row[k]
    for j in range(n):
        for k in range(j):mat[j][k]=mat[k][j]
    c=solve(mat,rhs)
    return [math.hypot(c[2*i],c[2*i+1]) for i in range(len(frequencies))]
def frequency(values):
    crossings=[]
    for i in range(1,len(values)):
        if values[i-1]<0<=values[i]:crossings.append(i-1-values[i-1]/(values[i]-values[i-1]))
    assert len(crossings)>20
    return (len(crossings)-1)*FS/(crossings[-1]-crossings[0])
def wavwrite(path,values,multiplier=1):
    pcm=array('h',(max(-32768,min(32767,x*multiplier)) for x in values))
    if sys.byteorder!='little':pcm.byteswap()
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(round(FS));w.writeframes(pcm.tobytes())
def main():
    cols=[array('q') for _ in range(18)]
    for index,line in enumerate((ROOT/'sim/expression_samples.txt').open()):
        row=list(map(int,line.split()));assert len(row)==18
        for dst,v in zip(cols,row):dst.append(v)
        assert row[0]==((sum(row[10:])//8)*row[1])//4194304,('mix',index)
        assert -512<=row[0]<=511 and 0<=row[1]<=65536
    assert len(cols[0])==24*SLOT
    mix=cols[0]
    assert not any(mix[:SLOT]) and not any(mix[23*SLOT:])
    assert not any(mix[5*SLOT+600:6*SLOT]),'Mute did not reach zero'
    def window(slot,col=0):return cols[col][slot*SLOT+17000:slot*SLOT+33000]
    stages=[]
    for slot,expected in [(1,[32,0,0]),(2,[24,0,8]),(3,[16,8,8]),(4,[4,2,2]),(6,[16,8,8])]:
        amps=fit(window(slot),[440,880,1320])
        assert all(abs(a-b)<.6 for a,b in zip(amps,expected)),('harmonics',slot,amps)
        stages.append({'slot':slot,'peak_codes':amps,'expected':expected})
    assert abs(frequency(window(1,10))/440-1) < .001
    # All successive glide steps stay bounded and monotonically reach exact targets.
    expected_step=lambda n:round(440*2**((n-69)/12)*2**32/FS)
    glide_results=[]
    for slot,target,direction in [(7,76,1),(8,69,-1)]:
        values=cols[8][slot*SLOT:(slot+1)*SLOT]
        diffs=[b-a for a,b in zip(values,values[1:])]
        assert all(0<=d*direction<=2048 for d in diffs)
        assert max(abs(d) for d in diffs)==2048
        assert values[-1]==expected_step(target)
        amps=fit(window(slot),[440*2**((target-69)/12)*k for k in (1,2,3)])
        assert abs(amps[0]-16)<.6,(slot,amps)
        glide_results.append({'slot':slot,'target_note':target,'endpoint_step':values[-1],'peak_codes':amps})
    bend_freq=expected_step(69)*73562//65536*FS/2**32
    bend_amps=fit(window(9),[bend_freq*k for k in (1,2,3)])
    assert abs(bend_amps[0]-16)<.6
    # Pedal states are independent of held keys. Check late stable parts only.
    for i in range(13*SLOT+17000,14*SLOT):assert cols[5][i]==0 and cols[6][i]==7 and cols[4][i]==7
    assert not any(mix[14*SLOT+20000:15*SLOT])
    for i in range(16*SLOT+17000,17*SLOT):assert cols[5][i]==0 and cols[6][i]==1 and cols[7][i]==1 and cols[4][i]==1
    assert not any(mix[17*SLOT+20000:18*SLOT])
    # Do not infer sustain correctness from state bits alone: independently fit audio.
    pedal_freqs=[440*2**((n-69)/12) for n in (60,64,67)]
    pedal_amps=fit(window(13),pedal_freqs);assert all(abs(a-32)<.6 for a in pedal_amps)
    sost_amps=fit(window(16),[440*2**((n-69)/12) for n in (72,76)])
    assert abs(sost_amps[0]-32)<.6 and sost_amps[1]<.3
    velocities=[]
    for slot,target in [(18,8),(19,16),(20,32)]:
        amp=fit(cols[0][slot*SLOT+14000:slot*SLOT+22000],[440])[0]
        assert abs(amp-target)<.6,(slot,amp)
        velocities.append({'velocity':{18:64,19:128,20:256}[slot],'peak_codes':amp})
    chord=[]
    for v,n in enumerate([48,52,55,60,64,67,72,76]):
        f=440*2**((n-69)/12)
        amp=fit(window(21,10+v),[f,2*f,3*f])
        assert abs(amp[0]-8191.75)<5 and abs(amp[1]-4095.875)<5 and abs(amp[2]-4095.875)<5,(n,amp)
        chord.append({'note':n,'frequency_hz':f,'harmonic_peak_codes':amp})
    assert all(x==255 for x in cols[4][21*SLOT+17000:22*SLOT])
    assert not any(mix[22*SLOT+20000:]),'Panic not released'
    clips=ROOT/'audio';clips.mkdir(exist_ok=True)
    wavwrite(clips/'00_full_demo_raw.wav',mix)
    wavwrite(clips/'00_full_demo_listen.wav',mix,32)
    segments=[('01_timbres',1,4),('02_volume',3,7),('03_glide_bend',6,11),
              ('04_pedals',11,18),('05_velocity',18,21),('06_eight_voices',21,24)]
    for name,lo,hi in segments:wavwrite(clips/(name+'.wav'),mix[lo*SLOT:hi*SLOT],32)
    report={'source':'RTL simulation; not board recording','samples':len(mix),'sample_rate_hz':FS,
        'range':[min(mix),max(mix)],'listening_gain':32,'harmonic_stages':stages,'glide':glide_results,
        'bend_frequency_hz':bend_freq,'bend_peak_codes':bend_amps,'sustain_peak_codes':pedal_amps,
        'sostenuto_peak_codes':sost_amps,'velocities':velocities,'eight_voices':chord,
        'checks':['exact_mix_all_samples','mute_exact_zero','pedal_audio_and_state','pitch_glide_monotonic',
                  'timbre_harmonics','velocity_ratios','eight_active_voices','panic_and_final_silence']}
    (ROOT/'sim/audio_analysis.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'AUDIO_ANALYSIS_PASS samples={len(mix)} range={min(mix)}..{max(mix)} clips={len(segments)+2}')
if __name__=='__main__':main()
