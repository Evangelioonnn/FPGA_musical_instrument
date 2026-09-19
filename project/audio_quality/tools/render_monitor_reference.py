"""Apply the timbre probe's integer attenuation to captured voice samples.

This isolates the numeric monitor stage. It does not record the board, recreate
probe command/init timing, or model the DAC, amplifier, headphone or transport.
The preview restores one fixed gain of 32 AFTER quantization, retaining its error.
"""
from pathlib import Path
import array
import hashlib
import json
import math
import sys
import wave

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'evidence/audio'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write_wav(path,samples,rate):
    data=array.array('h',samples)
    if sys.byteorder!='little': data.byteswap()
    with wave.open(str(path),'wb') as output:
        output.setparams((1,2,rate,0,'NONE','not compressed'))
        output.writeframes(data.tobytes())

def rms(samples):
    return math.sqrt(sum(x*x for x in samples)/len(samples))

def main():
    report={'source':'captured single-voice RTL WAV; numeric monitor transform only',
            'transform':'signed arithmetic shift right 5, clamp to [-512,511]',
            'preview_gain':32,'normalization':'none; same fixed gain for both',
            'board_recording':False,'models_probe_event_timing':False,'voices':{}}
    for voice in ('fm','pluck'):
        source=OUT/('candidate_'+voice+'_rtl.wav')
        with wave.open(str(source),'rb') as input_file:
            if input_file.getnchannels()!=1 or input_file.getsampwidth()!=2:
                raise ValueError('Expected mono signed16 PCM')
            rate=input_file.getframerate()
            values=array.array('h',input_file.readframes(input_file.getnframes()))
            if sys.byteorder!='little': values.byteswap()
        shifted=[int(x)>>5 for x in values]
        monitor=[max(-512,min(511,x)) for x in shifted]
        preview=[x*32 for x in monitor]
        raw_path=OUT/(voice+'_monitor_raw.wav')
        preview_path=OUT/(voice+'_monitor_preview.wav')
        write_wav(raw_path,monitor,rate)
        write_wav(preview_path,preview,rate)
        peak=max(map(abs,monitor))
        error=[y-int(x) for x,y in zip(values,preview)]
        report['voices'][voice]={'input':source.relative_to(ROOT).as_posix(),
            'input_sha256':sha(source),'samples':len(values),'wav_rate_hz':rate,
            'monitor_peak':peak,'monitor_peak_dbfs':20*math.log10(peak/32768),
            'monitor_rms':rms(monitor),'clamped_samples':sum(a!=b for a,b in zip(shifted,monitor)),
            'restored_preview_max_error_lsb':max(map(abs,error)),
            'restored_preview_rms_error_lsb':rms(error),
            'raw_file':raw_path.relative_to(ROOT).as_posix(),'raw_sha256':sha(raw_path),
            'preview_file':preview_path.relative_to(ROOT).as_posix(),'preview_sha256':sha(preview_path)}
    destination=ROOT/'evidence/timbre_rtl_2026-09-19/monitor_reference.json'
    destination.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    main()
