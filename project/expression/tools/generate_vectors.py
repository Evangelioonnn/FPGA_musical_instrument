"""Independent event-list oracle: timestamps rather than RTL rank registers."""
from pathlib import Path
import random,json,math
BASE=Path(__file__).resolve().parents[1]
def packed(parts):
    result=0
    for value,width in parts: result=(result<<width)|(value&((1<<width)-1))
    return result
def manager_vectors(n):
    rng=random.Random(2026091800+n)
    slots=[None]*n; notes=[0]*n; pitches=[0]*n; velocities=[0]*n
    prev=False; stamp=0; coverage={}
    def hit(key): coverage[key]=coverage.get(key,0)+1
    inputs=[(1,0,0,0,0,0,0,0,0,(1<<n)-1)]
    for note in range(60,60+n): inputs.append((0,1,0,note,0,256,0,0,0,0))
    inputs.extend([(0,0,0,0,0,0,0,1,0,0),(0,1,1,60,0,0,0,1,0,0),
        (0,1,0,80,0,128,1,1,0,0),(0,1,1,80,0,0,1,1,0,0),
        (0,0,0,0,0,0,0,0,0,0),(0,0,0,0,0,0,1,1,1,0)])
    for _ in range(12000):
        inputs.append((int(rng.random()<.006),int(rng.random()<.88),rng.choices([0,1,2,3],[45,35,18,2])[0],
            rng.randrange(55,85),rng.randrange(128),rng.choice([0,64,128,256,300]),
            int(rng.random()<.65),int(rng.random()<.55),int(rng.random()<.012),rng.randrange(1<<n)))
    lines=[]
    for reset,valid,kind,note,value,vel,sus,sos,panic,idle in inputs:
        ons=offs=fresh=stolen=ignored=0
        if reset:
            slots=[None]*n;notes=[0]*n;pitches=[0]*n;velocities=[0]*n;prev=False;stamp=0;hit('reset')
        else:
            for i,item in enumerate(slots):
                if item and not item['held'] and not item['gate'] and (idle>>i)&1:
                    slots[i]=None;hit('retire')
            for i,item in enumerate(slots):
                if item:
                    item['sost']=bool(sos and (item['sost'] if prev else item['held']))
                    if item['gate'] and not item['held'] and not sus and not item['sost']:
                        item['gate']=False;offs|=1<<i;hit('pedal_release')
            if panic:
                for i,item in enumerate(slots):
                    if item: item.update(held=False,gate=False,sost=False);offs|=1<<i
                hit('panic')
            elif valid:
                match=next((i for i,s in enumerate(slots) if s and notes[i]==note),None)
                if kind==0 and vel:
                    stamp+=1
                    if match is not None: idx=match;hit('retrigger')
                    else:
                        free=[i for i,s in enumerate(slots) if s is None]
                        if free: idx=free[0];hit('free')
                        else:
                            tail=[i for i,s in enumerate(slots) if not s['gate']]
                            pedal=[i for i,s in enumerate(slots) if not s['held']]
                            eligible=tail or pedal or list(range(n))
                            idx=min(eligible,key=lambda i: slots[i]['time'])
                            stolen=1;hit('steal_tail' if tail else 'steal_pedal' if pedal else 'steal_held')
                    if slots[idx] is None: fresh|=1<<idx
                    captured=slots[idx]['sost'] if match is not None else False
                    slots[idx]={'held':True,'gate':True,'sost':captured,'time':stamp}
                    notes[idx]=pitches[idx]=note;velocities[idx]=min(vel,256)
                    ons|=1<<idx;offs&=~(1<<idx)
                elif kind==1 or (kind==0 and not vel):
                    if match is not None and slots[match]['held']:
                        slots[match]['held']=False;hit('off')
                        if not sus and not slots[match]['sost']:
                            slots[match]['gate']=False;offs|=1<<match
                    else: ignored=1;hit('ignored')
                elif kind==2 and match is not None: pitches[match]=value;hit('retune')
                else: ignored=1;hit('ignored')
            prev=bool(sos)
        mask=lambda field:sum(1<<i for i,item in enumerate(slots) if item and (field is None or item[field]))
        flat=lambda values,width:sum(v<<(i*width) for i,v in enumerate(values))
        inp=packed([(reset,1),(valid,1),(kind,2),(note,7),(value,7),(vel,9),(sus,1),(sos,1),(panic,1),(idle,n)])
        out=packed([(ons,n),(offs,n),(fresh,n),(mask(None),n),(mask('held'),n),(mask('gate'),n),(mask('sost'),n),
                    (flat(notes,7),7*n),(flat(pitches,7),7*n),(flat(velocities,9),9*n),(stolen,1),(ignored,1)])
        lines.append(f'{inp:x} {out:x}')
    (BASE/f'sim/manager{n}_vectors.txt').write_text('\n'.join(lines)+'\n')
    return {'vectors':len(lines),'coverage':coverage}

def controls_vectors():
    rng=random.Random(20260918)
    defaults=[65536,0,65536,0,0,0,0,68,6,32768,3]
    limits=[(0,65536),(0,2),(32768,131072),(0,2147483647),(0,1),(0,1),(1,1),(1,65535),(1,65535),(0,65535),(1,65535)]
    regs=defaults[:];gain=65536;w2=w3=applied=0;lines=[]
    def approach(x,t,d): return x+max(-d,min(d,t-x))
    for i in range(9000):
        rst=int(i==0 or rng.random()<.002); ce=int(rng.random()<.82);valid=int(rng.random()<.18)
        addr=rng.randrange(16)
        data=rng.choice([0,1,2,3,32768,65535,65536,131072,2147483647,2147483648,4294967295,rng.randrange(131073)])
        if 10<i<530: valid=0;ce=1
        if i==10: valid=1;addr=0;data=0
        if i==600: valid=1;addr=1;data=2
        if 600<i<1200: valid=0;ce=1
        if rst: regs=defaults[:];gain=65536;w2=w3=applied=ack=accept=panic=0
        else:
            ack=valid;accept=int(valid and addr<len(limits) and limits[addr][0]<=data<=limits[addr][1]);panic=0
            if ce:
                gain=approach(gain,regs[0],128)
                w2=approach(w2,16384 if regs[1]==2 else 0,32)
                w3=approach(w3,16384 if regs[1] else 0,32)
            if valid: applied=data if accept else 4294967295
            if accept:
                if addr==6: panic=1
                else: regs[addr]=data
        inp=packed([(rst,1),(ce,1),(valid,1),(addr,4),(data,32)])
        out=packed([(ack,1),(accept,1),(applied,32),(regs[0],17),(gain,17),(regs[1],2),(w2,15),(w3,15),
                    (regs[2],18),(regs[3],31),(regs[4],1),(regs[5],1),(panic,1),*[(v,16) for v in regs[7:11]]])
        lines.append(f'{inp:x} {out:x}')
    (BASE/'sim/controls_vectors.txt').write_text('\n'.join(lines)+'\n')
    return len(lines)
def voice_vectors():
    rng=random.Random(92318);phase=0;lines=[];gates={'all_harmonics':0,'third_blocked':0,'both_blocked':0}
    for i in range(6000):
        base=rng.choice([0x01ffffff,0x2aaaaaaa,0x2aaaaaab,0x3fffffff,0x40000000,0x7fffffff,rng.randrange(2**32)])
        ratio=rng.choice([32768,65536,131072,rng.randrange(32768,131073)])
        w2=rng.randrange(16385);w3=rng.randrange(16385);velocity=rng.randrange(512)
        step=min(base*ratio//65536,0x7fffffff);phase=(phase+step)%2**32
        weights=[65536,w2 if 2*step<2**31 else 0,w3 if 3*step<2**31 else 0]
        weights[0]-=weights[1]+weights[2]
        values=[round(32767*math.sin(2*math.pi*((phase*h)%2**32//2**22)/1024)) for h in [1,2,3]]
        sample=(sum(w*v for w,v in zip(weights,values))//65536*65535//65536)*min(velocity,256)//256
        inp=packed([(base,32),(ratio,18),(w2,15),(w3,15),(velocity,9)])
        out=packed([(sample,16),(phase,32),(step,32)])
        lines.append(f'{inp:x} {out:x}')
        gates['all_harmonics' if 3*step<2**31 else 'third_blocked' if 2*step<2**31 else 'both_blocked']+=1
    (BASE/'sim/voice_vectors.txt').write_text('\n'.join(lines)+'\n')
    return {'vectors':len(lines),'harmonic_gate_coverage':gates}
if __name__=='__main__':
    result={str(n):manager_vectors(n) for n in [4,8]}
    result['controls_vectors']=controls_vectors()
    result['voice_numeric']=voice_vectors()
    (BASE/'sim/vector_coverage.json').write_text(json.dumps(result,indent=2)+'\n')
    print('ORACLE_VECTORS_READY',json.dumps(result))
