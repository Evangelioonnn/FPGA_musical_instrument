"""Independent integer oracle: mathematical ROM, exact rational amplitude."""
from pathlib import Path
import math
HERE=Path(__file__).resolve().parents[1]
def rounded(n,d):return (1 if n>=0 else -1)*((abs(n)+d//2)//d)
count=0
for line in (HERE/'sim/math_vectors.txt').read_text().splitlines():
    p,phase,env,bright,sample=map(int,line.split())
    shape=sum(w*round(32767*math.sin(2*math.pi*(((phase*h)&0xffffffff)>>20)/4096))
              for h,w in enumerate([128,32,16,8],1))
    expected=rounded(shape*env,2**(23+3*p))
    assert sample==expected,(p,phase,env,sample,expected)
    count+=1
assert count==4096,count
print(f'OUTPUT_MATH_ORACLE_PASS {count} exact independently calculated samples')
