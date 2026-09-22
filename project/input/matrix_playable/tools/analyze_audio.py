"""Independent reference arithmetic, fixed-gain WAV export and artifact fingerprints."""
from pathlib import Path
import argparse,hashlib,json,math,struct,wave
HERE=Path(__file__).resolve().parents[1]
FS=50_000_000/1040
TOTAL=769232
def analyze_reference(samples,event_path=None):
    events={}
    for line in (event_path or HERE/'sim/reference_events.txt').read_text().splitlines():
        kind,frame,slot,value=line.split();events.setdefault(int(frame),[]).append((kind,int(slot),int(value)))
    # Mathematical sine table, equal-tempered tuning and independent ADSR recurrence.
    sine=[round(32767*math.sin(2*math.pi*i/1024)) for i in range(1024)]
    voices={};gain=65536;mismatches=[]
    for n,actual in enumerate(samples):
        for kind,slot,value in events.get(n,[]):
            if kind=='ON':voices[slot]=dict(phase=0,step=round(440*2**((value-69)/12)*2**32/FS),level=0,state='A',release=3)
            else:voices[slot].update(state='R',release=value)
        expected=0
        for v in voices.values():
            v['phase']=(v['phase']+v['step'])%(2**32)
            if v['state']=='A':
                v['level']=min(65535,v['level']+68)
                if v['level']==65535:v['state']='D'
            elif v['state']=='D':
                v['level']=max(32768,v['level']-6)
                if v['level']==32768:v['state']='S'
            elif v['state']=='R':v['level']=max(0,v['level']-v['release'])
            expected+=sine[v['phase']>>22]*v['level']//2**22
        target=65536 if n<307692 or n>=365385 else 32768 if n<346154 else 0
        gain+=max(-128,min(128,target-gain))
        expected=max(-32768,min(32767,expected))
        value=abs(expected)*gain//65536
        expected=-value if expected<0 else value
        if expected!=actual and len(mismatches)<10:mismatches.append((n,actual,expected))
    if mismatches:raise AssertionError(('Reference independent oracle differs',mismatches))
    return {'samples':len(samples),'independent_mathematical_oracle':True,'exact_mismatches':0,'on_off_events':sum(map(len,events.values()))}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,default=HERE/'sim/audio');args=p.parse_args()
    args.output.mkdir(parents=True,exist_ok=True);report={}
    for name in ('reference','pluck','fm'):
        path=HERE/f'sim/{name}_samples.txt';samples=[int(x) for x in path.read_text().splitlines()]
        assert len(samples)==TOTAL,(name,len(samples))
        assert all(x==0 for x in samples[-4807:]),name+' has nonzero final 100ms'
        raw=struct.pack('<'+'h'*len(samples),*samples)
        assert max(map(abs,samples))*8<=32767,'Preview would clip'
        for label,mult in [('raw',1),('preview',8)]:
            output=args.output/f'matrix_{name}_{label}.wav'
            with wave.open(str(output),'wb') as w:
                w.setnchannels(2);w.setsampwidth(2);w.setframerate(round(FS))
                w.writeframes(b''.join(struct.pack('<hh',x*mult,x*mult) for x in samples))
        report[name]={'samples':len(samples),'peak':max(map(abs,samples)),'pcm_sha256':hashlib.sha256(raw).hexdigest(),'preview_gain':8,'rms':math.sqrt(sum(x*x for x in samples)/len(samples))}
        if name=='reference':report[name].update(analyze_reference(samples))
    (args.output/'audio_analysis.json').write_text(json.dumps(report,indent=2)+'\n')
    print('AUDIO_ANALYSIS_PASS '+json.dumps(report))
if __name__=='__main__':main()
