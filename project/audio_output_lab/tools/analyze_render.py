"""Check gain against independent Q16 oracle and export actual RTL streams."""
from pathlib import Path
import math,json,wave,hashlib
import numpy as np
HERE=Path(__file__).resolve().parents[1];SIM=HERE/'sim'
a=np.loadtxt(SIM/'render_1_0.txt',dtype=np.int64)
assert a.shape==(150600,17),a.shape
assert not np.any((a[:,1:]>=32767)|(a[:,1:]<=-32768))
max_error=0
for v in range(2):
    for k in range(7):
        target=round(65536*10**((18+k-24)*3/20))
        # Reset value is unity; then slew by at most 128 per valid sample.
        gains=np.maximum(target,65536-128*np.arange(1,len(a)+1))
        products=a[:,1+v]*gains
        expected=np.sign(products)*(np.abs(products)//65536)
        actual=a[:,3+v*7+k]
        error=int(np.max(np.abs(expected-actual)));max_error=max(max_error,error)
        assert error==0,(v,k,error)
audio=SIM/'audio';audio.mkdir(exist_ok=True)
def write(name,pcm):
    with wave.open(str(audio/(name+'.wav')),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(48077)
        f.writeframes(np.repeat(pcm.astype('<i2')[:,None],2,axis=1).tobytes())
write('control_volume18',a[:,3]);write('control_volume24',a[:,9]);write('headroom_volume24',a[:,16])
write('polarity_volume24',-a[:,9])
metrics=[]
for section in range(1,15):
    rows=a[a[:,0]==section]
    metrics.append({'section':section,'samples':len(rows),
        'control_peaks_volume18_to24':[int(np.max(np.abs(rows[:,3+k]))) for k in range(7)],
        'headroom_peaks_volume18_to24':[int(np.max(np.abs(rows[:,10+k]))) for k in range(7)]})
rec={'samples':len(a),'gain_checks':len(a)*14,'max_gain_error':max_error,
     'peak_control':int(np.max(np.abs(a[:,1]))),'peak_headroom':int(np.max(np.abs(a[:,2]))),
     'clip_samples':0,'sections':metrics,
     'wav_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(audio.glob('*.wav'))}}
(SIM/'render_results.json').write_text(json.dumps(rec,indent=2)+'\n')
print(json.dumps({k:v for k,v in rec.items() if k not in ('sections','wav_sha256')},indent=2))
print('OUTPUT_RENDER_ORACLE_PASS independent gain/ramp checks; no automatic normalization')
