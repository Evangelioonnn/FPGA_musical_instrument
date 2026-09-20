"""Export actual RTL PCM, with fixed preview gain and objective acceptance checks."""
from pathlib import Path
import argparse
import array
import hashlib
import json
import math
import sys
import wave
from create_projects import HERE, ROOT

FS=50_000_000/1040
NAMES=('performance','volume','timbre','release','echo','pitch','pedals')
OUT=ROOT/'evidence/audio'
REPORT=ROOT/'evidence/knob_suite_2026-09-20'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def save(path,values):
    data=array.array('h',values)
    if sys.byteorder!='little':data.byteswap()
    with wave.open(str(path),'wb') as output:
        output.setparams((1,2,round(FS),0,'NONE','not compressed'))
        output.writeframes(data.tobytes())

def window(values,a,b):return values[round(a*FS):round(b*FS)]

def frequency(values):
    edges=[i for i in range(1,len(values)) if values[i-1]<0<=values[i]]
    if len(edges)<10:raise AssertionError('Not enough zero crossings')
    return (len(edges)-1)*FS/(edges[-1]-edges[0])

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sim-dir',type=Path,default=HERE/'sim')
    args=parser.parse_args()
    OUT.mkdir(exist_ok=True);REPORT.mkdir(exist_ok=True)
    pcm={};report={'source':'RTL simulation, not board recording','fs_hz_exact':FS,
        'wav_header_rate':round(FS),'preview_gain':8,'per_segment_normalization':False,'audio':{}}
    for name in NAMES:
        samples=[int(v) for v in (args.sim_dir/(name+'_samples.txt')).read_text().split()]
        expected=240385 if name=='pitch' else 384616
        assert len(samples)==expected,(name,len(samples))
        assert all(-32768<=x<=32767 for x in samples)
        peak=max(map(abs,samples));assert 0<peak<4096,(name,peak)
        raw=OUT/('knob_'+name+'_raw.wav');preview=OUT/('knob_'+name+'_preview.wav')
        save(raw,samples);save(preview,[x*8 for x in samples]);pcm[name]=samples
        report['audio'][name]={'samples':len(samples),'seconds':len(samples)/FS,'peak_raw':peak,
            'rms_raw':math.sqrt(sum(x*x for x in samples)/len(samples)),
            'raw_file':raw.relative_to(ROOT).as_posix(),'raw_sha256':sha(raw),
            'preview_file':preview.relative_to(ROOT).as_posix(),'preview_sha256':sha(preview)}
    observed=frequency(window(pcm['performance'],.25,.65))
    expected_hz=440*2**((61-69)/12)
    cents=1200*math.log2(observed/expected_hz)
    assert abs(cents)<5,cents
    assert not any(window(pcm['performance'],5.1,8))
    assert not any(window(pcm['volume'],1.2,2.9))
    assert any(window(pcm['volume'],3.2,3.6))
    assert pcm['echo'][:47000]==pcm['release'][:47000]
    assert pcm['echo'][7*48077:8*48077]==pcm['echo'][:48077]
    assert not any(window(pcm['pedals'],6.5,8))
    assert not any(window(pcm['pitch'],4.5,5))
    lengths=[]
    for frame_start,release_step in ((0,3),(57692,96),(173076,1)):
        # Each release-mode note holds 9615 samples, reaches the unchanged
        # sustain level, then takes ceil(32768/R) envelope sample ticks to zero.
        block=pcm['release'][frame_start:frame_start+57692]
        last=max(i for i,x in enumerate(block) if x!=0)
        expected_last=9615+math.ceil(32768/release_step)
        assert abs(last-expected_last)<250,(frame_start,last,expected_last)
        lengths.append({'start_sample':frame_start,'release_step':release_step,
                        'last_nonzero_sample_offset':last,'expected_envelope_end_offset':expected_last})
    report['checks']={'performance_first_note_midi':61,'frequency_hz':observed,'pitch_error_cents':cents,
        'performance_tail_silent':True,'volume_mute_and_restore':True,
        'echo_disabled_matches_dry':True,'echo_return_to_dry_exact':True,
        'release_lengths':lengths,'pedal_and_pitch_tails_silent':True}
    (REPORT/'audio_analysis.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('KNOB_AUDIO_EXPORT_PASS files=14 fixed_gain=8 pitch_cents='+str(round(cents,5)))

if __name__=='__main__':main()
