"""Generate listening WAVs from RTL samples, never load PCM into the FPGA."""
from pathlib import Path
import subprocess,sys,array,wave,json,hashlib
lab=Path(__file__).resolve().parents[1];out=lab/'sim/audio';out.mkdir(exist_ok=True)
subprocess.run([sys.executable,str(lab/'sim/run.py'),'--test','looper_preview_tb','--timeout','1800'],check=True)
manifest={}
for name in ['piano','warm_pluck','bell','drive_lead','custom','drum_kit','metronome120']:
    samples=[int(x) for x in (out/(name+'.txt')).read_text().splitlines()]
    peak=max(map(abs,samples));scale=15000/peak if peak else 1
    # Audition-only fixed per-file gain, no compressor/active-voice normalization.
    data=array.array('h',(round(x*scale) for x in samples))
    if sys.byteorder!='little':data.byteswap()
    path=out/(name+'.wav')
    with wave.open(str(path),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(48077);w.writeframes(data.tobytes())
    manifest[name]={'samples':len(samples),'raw_peak':peak,'audition_gain':scale,
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'wave_rate_hz':48077,
        'rtl_logical_rate_hz':50000000/1040,'scope':'N1/P1 dry pre-master, CE64 offline accelerated; NOT full-top output or deadline proof'}
(lab/'results/preview.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest,indent=2),flush=True)
