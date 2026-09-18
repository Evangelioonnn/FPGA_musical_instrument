"""Independent allocation oracle: dictionary + recency list, not RTL rank arithmetic."""
from pathlib import Path
import json
import random

ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(20260918)
notes=[0]*4
busy=[False]*4
held=[False]*4
order=list(range(4))
coverage={k:0 for k in ('reset','retire','free','retrigger','release_steal','held_steal','off','ignored','panic')}
rows=[]

def mask(flags):
    return sum(int(x)<<i for i,x in enumerate(flags))

def emit(note=0,on=0,valid=0,idle=0,panic=0,reset=0):
    global notes,busy,held,order
    ons=offs=stolen=ignored=0
    if reset:
        notes=[0]*4; busy=[False]*4; held=[False]*4; order=list(range(4))
        coverage['reset']+=1
    else:
        for i in range(4):
            if busy[i] and not held[i] and (idle>>i)&1:
                busy[i]=False; coverage['retire']+=1
        if panic:
            offs=mask(busy); held=[False]*4; coverage['panic']+=1
        elif valid:
            matching=[i for i in range(4) if busy[i] and notes[i]==note]
            if on:
                if matching:
                    choice=matching[0]; coverage['retrigger']+=1
                else:
                    free=[i for i in range(4) if not busy[i]]
                    tails=[i for i in order if busy[i] and not held[i]]
                    if free: choice=free[0]; coverage['free']+=1
                    elif tails: choice=tails[0]; coverage['release_steal']+=1; stolen=1
                    else: choice=next(i for i in order if busy[i]); coverage['held_steal']+=1; stolen=1
                notes[choice]=note; busy[choice]=True; held[choice]=True
                order.remove(choice); order.append(choice); ons=1<<choice
            elif matching and held[matching[0]]:
                choice=matching[0]; held[choice]=False; offs=1<<choice; coverage['off']+=1
            else: ignored=1; coverage['ignored']+=1
    packed=sum(n<<(7*i) for i,n in enumerate(notes))
    values=(reset,panic,valid,on,note,idle,int(not reset and not panic),mask(busy),mask(held),packed,ons,offs,stolen,ignored)
    rows.append(' '.join(format(x,'x') for x in values))
    assert len({notes[i] for i in range(4) if busy[i]})==sum(busy)

emit(reset=1)
for n in (60,64,67,72,76): emit(n,1,1)
emit(60,0,1)  # stale off after steal
emit(67,0,1); emit(79,1,1)  # released voice preferred over oldest held
emit(64,1,1); emit(64,0,1); emit(64,1,1)  # held/release retriggers
emit(72,0,1); emit(idle=8); emit(84,1,1)
emit(panic=1,valid=1,on=1,note=90); emit(idle=15)
emit(0,1,1); emit(127,1,1); emit(reset=1)
for cycle in range(6000):
    available=[notes[i] for i in range(4) if busy[i]]
    note=rng.choice(available) if available and rng.random()<0.45 else rng.randrange(128)
    idle=mask([rng.random()<0.2 for _ in range(4)])
    emit(note,int(rng.random()<0.63),int(rng.random()<0.8),idle,
         int(rng.random()<0.015),int(rng.random()<0.003))
assert all(v>0 for v in coverage.values()),coverage
(ROOT/'sim/manager_vectors.txt').write_text('\n'.join(rows)+'\n',encoding='ascii')
(ROOT/'sim/manager_coverage.json').write_text(json.dumps(dict(vectors=len(rows),seed=20260918,coverage=coverage),indent=2)+'\n',encoding='utf-8')
print('MANAGER_VECTORS_READY',len(rows),coverage)
