"""Current RTL -> raw PCM -> fixed and explicitly amplified audition WAVs."""
from pathlib import Path
import subprocess,sys,array,wave,json,hashlib,argparse
lab=Path(__file__).resolve().parents[1];root=lab.parents[1];out=lab/'sim/audio';out.mkdir(exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--resume',action='store_true')
p.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
p.add_argument('--timeout',type=int,default=4800);args=p.parse_args()
names=['piano','warm_pluck','bell','drive_lead','custom','drum_kit','metronome120']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for test,raws in [('looper_preview_tb',[n+'.txt' for n in names]),('arrangement_preview_tb',['arrangement.txt'])]:
    rp=lab/'results/sim'/(test+'.json')
    current=False
    if args.resume and rp.exists():
        r=json.loads(rp.read_text(encoding='utf-8'))
        current=r.get('pass') and all((root/k).exists() and sha(root/k)==v for k,v in r['sources'].items()) and all((out/n).exists() and (out/n).stat().st_size>0 for n in raws)
    if not current:subprocess.run([sys.executable,str(lab/'sim/run.py'),'--modelsim',args.modelsim,'--test',test,'--timeout',str(args.timeout)],check=True)
manifest={}
def emit(name,raw,channels,values,gain,scope):
    if not values or len(values)%channels:raise RuntimeError('Invalid PCM length '+name)
    encoded=[round(x*gain) for x in values]
    if min(encoded)<-32768 or max(encoded)>32767:raise RuntimeError('WAV conversion clipping '+name)
    data=array.array('h',encoded)
    if sys.byteorder!='little':data.byteswap()
    path=out/(name+'.wav')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(channels);w.setsampwidth(2);w.setframerate(48077);w.writeframes(data.tobytes())
    with wave.open(str(path),'rb') as w:
        if w.readframes(w.getnframes())!=data.tobytes():raise RuntimeError('WAV PCM roundtrip mismatch '+name)
    manifest[name]={'frames':len(values)//channels,'channels':channels,'raw_peak':max(map(abs,values)),
      'fixed_gain':gain,'sha256':sha(path),'pcm_source':raw,'pcm_source_sha256':sha(out/raw),
      'wave_rate_hz':48077,'rtl_logical_rate_hz':50000000/1040,'scope':scope,'pcm_roundtrip_verified':True,
      'generator_source':Path(__file__).resolve().relative_to(root).as_posix(),
      'generator_source_sha256':sha(Path(__file__).resolve())}
    if name=='drum_kit':manifest[name]['pad_order']=[0,1,2,3,4,9,5,6,7,8,12,13]
for n in names:
    raw=n+'.txt';samples=[int(x) for x in (out/raw).read_text().splitlines()];peak=max(map(abs,samples))
    emit(n,raw,1,samples,6 if n=='drum_kit' else (15000/peak if peak else 1),'N1/P1 dry pre-master (drums/click own engine), offline CE64; fixed audition gain; not full-top/deadline/analog proof')
samples=[int(x) for x in (out/'arrangement.txt').read_text().split()];peak=max(map(abs,samples))
scope='Actual audio_core N8/P4 final stereo PCM with five tones, drums/click, layer expression/glide and track fade; room pipeline present but bypassed; offline CE256, not stored-event roundtrip or 32-voice deadline proof. Active FX covered separately by full-load regression'
emit('arrangement_fixed','arrangement.txt',2,samples,1,scope)
emit('arrangement_audition','arrangement.txt',2,samples,15000/peak if peak else 1,scope+'; fixed per-file audition gain')
(lab/'results/preview.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('WAV_PCM_ROUNDTRIP_PASS files='+str(len(manifest)),flush=True)
print(json.dumps({n:{k:v for k,v in r.items() if k in ['frames','raw_peak','fixed_gain']} for n,r in manifest.items()},indent=2))
