"""Independent integer synthesis model, using the frozen mathematical ROM.

Deliberately does not parse engine case statements. Pad/pitch/envelope/gain
expectations below are the revised specification, not derived from DUT output.
"""
from pathlib import Path
import hashlib, json, re, math, datetime
lab=Path(__file__).resolve().parents[1];root=lab.parents[1]
rom=root/'project/final_dual_timbre/src/sine_rom.v'
table=[None]*1024
for a,v in re.findall(r"10'd(\d+): data <= 16'h([0-9A-Fa-f]+)",rom.read_text()):
    n=int(v,16);table[int(a)]=n-65536 if n>=32768 else n
assert all(x is not None for x in table)
assert table==[round(32767*math.sin(2*math.pi*k/1024)) for k in range(1024)], 'Mathematical ROM differs'
pitch={0:8900000,1:16500000,2:13117318,3:17509518,4:22060612,9:26234636,
       5:37700000,6:127000000,7:160000000,8:174000000,12:18800000,13:28400000}
toms={2,3,4,9}
decay={0:10,1:9,2:10,3:10,4:10,9:10,5:9,6:11,7:13,8:14,12:10,13:10}
def signed16(x):return (x+32768)%65536-32768
def reference(p,v,n):
    phase=0;step=pitch[p];floor=step//2 if p==0 or p in toms else step
    level=0;target=v*257;attacked=False;active=True;previous=0
    noise=0x9e37 ^ {0:2,5:6,6:8}.get(p,p)
    attack=7 if p==0 or p==1 or p in toms else 6 if p in {6,7,8} else 4
    output=[]
    for _ in range(n):
        sine=table[phase>>22];white=32767 if noise&1 else -32768
        if p==0 or p in toms:wave=sine
        elif p in {7,8}:
            metal=8191 if ((phase>>31)^(phase>>28)^(phase>>25)^(phase>>22))&1 else -8192
            wave=max(-32768,min(32767,(white>>2)+((white-previous)>>2)+metal))
        elif p==1:wave=(sine>>1)+(white>>1)
        else:
            metal=16383 if ((phase>>31)^(phase>>27)^(phase>>24))&1 else -16384
            wave=signed16((white>>1)+metal)
        y=(wave*level)>>16 if active else 0
        if p in toms:y+=y>>3
        elif p in {5,6}:y>>=1
        output.append(y)
        if active:
            phase=(phase+step)&0xffffffff
            if p==0 or p in toms:step=max(floor,step-(step>>9))
            previous=white
            noise=((noise<<1)|(((noise>>15)^(noise>>13)^(noise>>12)^(noise>>10))&1))&65535
            if noise==0:noise=1
            if not attacked and level<target:
                level=min(target,level+((target-level)>>attack)+1)
                if level==target:attacked=True
            else:
                level=max(0,level-(level>>decay[p])-1)
                if level==0:active=False
    return output
sources={rom.relative_to(root).as_posix():hashlib.sha256(rom.read_bytes()).hexdigest(),
         Path(__file__).resolve().relative_to(root).as_posix():hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
vector_record=json.loads((lab/'results/sim/drum_revision_tb.json').read_text())
for path,h in vector_record['sources'].items():
    if hashlib.sha256((root/path).read_bytes()).hexdigest()!=h:raise RuntimeError('Stale drum RTL vector '+path)
results=[]
for p in pitch:
    for v in [64,127,255]:
        f=lab/f'sim/audio/drum_vector_{p}_{v}.txt'
        actual=[int(x) for x in f.read_text().split()];expected=reference(p,v,len(actual))
        for k,(a,e) in enumerate(zip(actual,expected)):
            if a!=e:raise AssertionError(f'pad{p} vel{v} sample{k}: DUT={a} independent={e}')
        if len(actual)!=4096:raise AssertionError('Missing frames')
        peak=max(map(abs,actual));assert peak<=36864
        results.append({'pad':p,'velocity':v,'frames':len(actual),'peak':peak,'pcm_sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
report={'pass':True,'time':datetime.datetime.now().astimezone().isoformat(),'comparisons':sum(x['frames'] for x in results),
        'single_slot_bound':36864,'eight_slot_pre_shift_bound':294912,'drums_post_shift_bound':18432,
        'click_bound':7680,'auxiliary_bound':26112,'sources':sources,'rtl_sources':vector_record['sources'],
        'tom_fundamental_hz':{str(p):(pitch[p]//2)*50000000/1040/2**32 for p in toms},'vectors':results}
(lab/'results/DRUM_MATH.json').write_text(json.dumps(report,indent=2))
print(f'DRUM_MATH_PASS samples={report["comparisons"]} unchanged_oracle_also_required slot_bound=36864 auxiliary_bound=26112')
