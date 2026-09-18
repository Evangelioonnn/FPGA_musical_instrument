"""Independent physical-owner dictionary and integer sensor reference."""
from pathlib import Path
import random
root=Path(__file__).resolve().parents[1]/'sim'
rng=random.Random(20260919)
owners={};states=[];events=[]
mapping=[60,60,64,67]
cases=[(1,mapping),(3,mapping),(2,[72,72,76,79]),(0,mapping),(15,mapping),(0,mapping)]
cases += [(rng.randrange(16),[rng.randrange(55,76) for _ in range(4)]) for _ in range(2000)]
for mask,notes in cases:
    velocity=rng.choice([64,128,256,300]);v=min(256,velocity);before=len(events)
    for key in list(sorted(owners)):
        if not mask>>key&1:
            note=owners.pop(key)
            if note not in owners.values():events.append((1<<16)|(note<<9)|v)
    for key in range(4):
        if mask>>key&1 and key not in owners:
            note=notes[key]
            if note not in owners.values():events.append((note<<9)|v)
            owners[key]=note
    packed=sum(note<<(7*k) for k,note in enumerate(notes))
    states.append(f'{mask:x} {packed:07x} {velocity} {len(events)-before}')
(root/'key_states.txt').write_text('\n'.join(states)+'\n')
(root/'key_events.txt').write_text('\n'.join(f'{x:05x}' for x in events)+'\n')
gain=0;lines=[]
for _ in range(1200):
    lo=rng.randrange(700);hi=rng.randrange(500,4096);dead=rng.randrange(200);raw=rng.randrange(4096)
    invalid=int(hi<=lo+dead)
    if invalid:target=0;gain=0
    else:
        target=max(0,min(65536,(raw-lo-dead)*65536//(hi-lo-dead)))
        delta=abs(target-gain);delta=max(1,delta>>3) if delta else 0
        gain+=delta if target>gain else -delta
    lines.append(f'{raw} {lo} {hi} {dead} {target} {gain} {invalid}')
(root/'pressure_vectors.txt').write_text('\n'.join(lines)+'\n')
print(f'INPUT_VECTORS states={len(states)} events={len(events)} pressure={len(lines)}')
volume=gain=target=65536;sustain=sostenuto=applied=0;controls=[]
for k in range(10000):
    reset=int(k==0 or rng.random()<.002)
    ce=int(rng.random()<.4);valid=int(rng.random()<.7);addr=rng.randrange(16)
    data=rng.choice([0,1,32768,65536,65537,0xffffffff,68])
    pressure=rng.choice([0,16384,32768,65536,70000])
    legal=(addr==0 and data<=65536) or (addr in (4,5) and data<=1) or (addr==6 and data==1)
    if reset:volume=gain=target=65536;sustain=sostenuto=applied=ack=accepted=panic=0
    else:
        next_target=volume*min(pressure,65536)//65536
        if ce:gain+=max(-128,min(128,target-gain))
        target=next_target;ack=valid;accepted=valid and legal;panic=0
        if valid:
            applied=data if legal else 0xffffffff
            if legal:
                if addr==0:volume=data
                if addr==4:sustain=data
                if addr==5:sostenuto=data
                if addr==6:panic=1;sustain=sostenuto=0
    controls.append(' '.join(str(int(x)) for x in [reset,ce,valid,addr,data,pressure,ack,accepted,applied,volume,gain,sustain,sostenuto,panic]))
(root/'controls_vectors.txt').write_text('\n'.join(controls)+'\n')
