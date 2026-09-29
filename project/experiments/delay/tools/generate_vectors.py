"""Independent sample-history oracle: no replication of RAM pointer/RTL schedule."""
from pathlib import Path
import random
ROOT=Path(__file__).resolve().parents[1]/'sim'
def trunc(x):return x//32768 if x>=0 else -((-x)//32768)
def sat(x):return min(32767,max(-32768,x))
for delay in (8,4096):
    random1=random.Random(915+delay)
    history=[];wet=0;rows=[]
    stimuli=[(0,1,False)]*100+[(25000,0,False)]+[(0,0,False)]*(delay*45)
    stimuli += [(-30000,0,True)]+[(0,0,False)]*(delay*45)
    stimuli += [(random1.randint(-32768,32767),int((i//180)%2==0),i==2000) for i in range(5000)]
    stimuli += [(32767,0,False)]*(delay+100)
    stimuli += [(0,1,False)]*100
    for x,bypass,reset in stimuli:
        if reset:history=[];wet=0
        target=0 if bypass else 16384
        wet+=min(256,target-wet) if target>wet else -min(256,wet-target)
        old=history[-delay] if len(history)>=delay else 0
        total=x+trunc(old*wet)
        history.append(sat(x+trunc(old*24576)))
        rows.append(f'{x} {bypass} {sat(total)} {int(total>32767 or total< -32768)} {-1 if reset else random1.randrange(3)}\n')
    assert all(int(row.split()[2])==0 for row in rows[100+delay*40:100+delay*45])
    (ROOT/f'delay{delay}_vectors.txt').write_text(''.join(rows),encoding='ascii')
    print(f'DELAY_ORACLE D={delay} samples={len(rows)}')
