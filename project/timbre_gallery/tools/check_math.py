"""Independent integer oracle for generated sine ROM and preset arithmetic."""
from pathlib import Path
import math
HERE=Path(__file__).resolve().parents[1]
MASK=(1<<32)-1
def sine(p):return round(math.sin(2*math.pi*((p&MASK)>>20)/4096)*32767)
def rounded(n,d):return ((abs(n)+d//2)//d)*(1 if n>=0 else -1)
count=0;maxpcm=[0]*8
for row in (HERE/'sim/gallery_math.txt').read_text().splitlines():
    t,phase,env,bright,actual=map(int,row.split())
    a,b,c,d=[sine(phase*h) for h in (1,2,3,4)]
    if t==2:shape=96*a+56*b+32*c+16*d
    elif t==3:shape=192*a+24*b+8*c
    elif t in (4,5):shape=128*a+16*b+64*c+16*d
    elif t in (6,7):
        mod=(b if t==6 else c)*bright
        shifted=phase+(mod>>(3 if t==6 else 1))
        carrier=sine(shifted)
        upper=32*b+8*c if t==6 else 16*b+16*c
        shape=(128 if t==6 else 96)*carrier+(upper*bright>>16)
    else:shape=128*a+32*b+16*c+8*d
    if t==5:
        boosted=shape*2
        shape=boosted if -3000000<=boosted<=3000000 else (
            3000000+((boosted-3000000)>>2) if boosted>0 else
            -3000000+((boosted+3000000)>>2))
    expected=rounded(shape*env,1<<23)
    assert actual==expected,(t,phase,env,bright,actual,expected)
    maxpcm[t]=max(maxpcm[t],abs(actual));count+=1
assert count==12288,count
print('GALLERY_MATH_ORACLE_PASS',count,'vectors, sampled max Q4:',maxpcm)
