"""Render actual eight-voice RTL PCM. Compile with sim/run.py first."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,subprocess,re,json,hashlib,wave,math
import numpy as np
from generate import HERE,VARIANTS
SIM=HERE/'sim'
def run(profile,modelsim,fast=1,short=0):
    tag=f'render_{profile}_{fast}_{short}'
    r=subprocess.run([str(Path(modelsim)/'vsim.exe'),'-c','-lib','work_palette','palette_render_tb',
        f'-gPROFILE={profile}',f'-gFAST={fast}',f'-gSHORT={short}','-l',tag+'.log',
        '-wlf',tag+'.wlf','-do','run -all; quit -f'],cwd=SIM,capture_output=True,text=True,errors='replace')
    log=r.stdout+'\n'+r.stderr
    (SIM/(tag+'.log')).write_text(log,encoding='utf-8')
    if r.returncode or re.search(r'\*\* (Error|Fatal)',log) or 'PALETTE_RENDER_TB_PASS' not in log:
        print(log,flush=True);raise RuntimeError(tag)
    print(next(l for l in log.splitlines() if 'PALETTE_RENDER_TB_PASS' in l),flush=True)
    return profile
def write_wav(path,a):
    # Header uses nearest integer to exact hardware Fs, error 1.6 ppm.
    with wave.open(str(path),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(48077)
        f.writeframes(np.repeat(a.astype('<i2')[:,None],2,axis=1).tobytes())
def analyze():
    audio=SIM/'audio';audio.mkdir(exist_ok=True)
    stats=[];arrays=[]
    for p,name in enumerate(VARIANTS):
        a=np.loadtxt(SIM/f'palette_{p}.txt',dtype=np.int32)
        assert len(a)==151300,(p,len(a))
        assert np.max(np.abs(a))<32767
        assert np.all(a[:100]==0)
        arrays.append(a)
        write_wav(audio/(name+'.wav'),a)
        rms=float(np.sqrt(np.mean(a[2000:12000].astype(float)**2)))
        stats.append({'variant':name,'samples':len(a),'duration_seconds':len(a)/(50e6/1040),
          'peak':int(np.max(np.abs(a))),'first_C4_rms':rms,'mean_pcm':float(a.mean()),
          'clip_samples':int(np.sum((a==32767)|(a==-32768))),
          'pcm_sha256':hashlib.sha256(a.astype('<i2').tobytes()).hexdigest()})
    # Compare within instrument families. Matching all DDS presets to the
    # much quieter legacy pluck level would discard useful playback bits.
    # Raw files stay unchanged; matched files only attenuate within a group.
    for i,(a,s) in enumerate(zip(arrays,stats)):
        group=stats[:5] if i<5 else stats[5:]
        target=min(x['first_C4_rms'] for x in group)
        s['matched_group']='DDS' if i<5 else 'pluck'
        gain=target/s['first_C4_rms'];s['matched_gain']=gain
        write_wav(audio/(s['variant']+'_matched.wav'),np.rint(a*gain))
    (SIM/'render_results.json').write_text(json.dumps(stats,indent=2)+'\n')
    print(json.dumps(stats,indent=2),flush=True)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
    ap.add_argument('--workers',type=int,default=3);ap.add_argument('--cadence',action='store_true')
    ap.add_argument('--analyze-only',action='store_true');a=ap.parse_args()
    if a.cadence:
        for p in (0,2,5,6):
            run(p,a.modelsim,0,1);run(p,a.modelsim,1,1)
            assert (SIM/f'cadence_{p}_0.txt').read_bytes()==(SIM/f'cadence_{p}_1.txt').read_bytes(),('cadence mismatch',p)
        print('CADENCE_EQUIVALENCE_PASS: real 1040 vs idle-clock-elided PCM',flush=True)
        return
    if not a.analyze_only:
        with ThreadPoolExecutor(max_workers=a.workers) as pool:
            futures=[pool.submit(run,p,a.modelsim) for p in range(7)]
            for f in as_completed(futures):f.result()
    analyze()
if __name__=='__main__':main()
