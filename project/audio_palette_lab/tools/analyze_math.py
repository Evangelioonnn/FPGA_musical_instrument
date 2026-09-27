"""Independent integer and continuous sine references; no HDL parsing."""
from pathlib import Path
import math,json
HERE=Path(__file__).resolve().parents[1]
def round_shift(x,n):return ((x+(1<<(n-1)))>>n) if x>=0 else -(((-x)+(1<<(n-1)))>>n)
def oracle(p,phase,env,bright):
    points=1024 if p==0 else 4096
    waves=[round(32767*math.sin(2*math.pi*((phase*h>> (22 if p==0 else 20))%points)/points)) for h in (1,2,3,4)]
    a,b,c,d=waves
    if p==0:return (((a//2+b//8+c//16+d//32)*env)>>19)*16
    if p==2:fund=160*a;upper=(32*b+8*c)*bright//65536
    elif p==3:fund=128*a;upper=(64*b+32*c+16*d)*bright//65536
    elif p==4:fund=144*a;upper=24*c
    else:fund=128*a;upper=32*b+16*c+8*d
    return round_shift((fund+upper)*env,23)
def main():
    rows=[list(map(int,l.split())) for l in (HERE/'sim/math_vectors.txt').read_text().splitlines()]
    worst=[0.0]*7;peaks=[0]*7
    for p,phase,env,bright,got in rows:
        expected=oracle(p,phase,env,bright)
        assert got==expected,(p,phase,env,got,expected)
        s=[32767*math.sin(2*math.pi*phase*h/2**32) for h in (1,2,3,4)]
        coeff=[128,32,16,8]
        if p==2:coeff=[160,32*bright/65536,8*bright/65536,0]
        if p==3:coeff=[128,64*bright/65536,32*bright/65536,16*bright/65536]
        if p==4:coeff=[144,0,24,0]
        ideal=sum(a*b for a,b in zip(s,coeff))*env/2**23
        worst[p]=max(worst[p],abs(got-ideal)/16)
        peaks[p]=max(peaks[p],abs(got)/16)
        # Conservative phase-lookup + quantization error bound, PCM LSB.
        bound=(sum(abs(c) for c in coeff)*32767*2*math.pi/(1024 if p==0 else 4096)+256)*env/2**27+2
        assert abs(got/16-ideal/16)<=bound
        assert abs(got)<=4096*16 # fixed 8-voice headroom, no per-active gain
        if env==0:assert got==0
    result={'vectors':len(rows),'integer_exact':True,'continuous_sine_max_error_pcm_lsb':worst,
            'random_vector_peak_pcm':peaks,'zero_envelope_exact_zero':True}
    out=HERE/'sim/math_results.json';out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
