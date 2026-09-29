from pathlib import Path
import argparse
import math
import random
import re
import subprocess
import wave
import struct
import hashlib
import json

HERE = Path(__file__).resolve().parent
LAB = HERE.parent
FS = 50_000_000 / 1040
parser = argparse.ArgumentParser()
parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--frame-clocks', type=int, default=1040)
args = parser.parse_args()
if args.frame_clocks < 25:
    raise ValueError('Frame spacing must satisfy the >=25 clock contract')
source_hashes={path.name: hashlib.sha256(path.read_bytes()).hexdigest()
               for path in (LAB / 'src').glob('*.v')}


def run(tool, options):
    result = subprocess.run([str(Path(args.modelsim) / tool), *options], cwd=HERE,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)', log):
        raise RuntimeError(log[-6000:])
    return log


def trunc(value, denominator):
    return value // denominator if value >= 0 else -((-value) // denominator)


rng = random.Random(20260928)
vectors = [(0, 0, 128)] * 1024
sections = {'bypass': (0, len(vectors))}
vectors += [(0, 1, 128)] * 160
sections['impulse'] = (len(vectors), len(vectors) + 40000)
vectors += [(32767, 1, 128)] + [(0, 1, 128)] * 39999
sections['positive_dc'] = (len(vectors), len(vectors) + 8000)
vectors += [(32767, 1, 511)] * 8000
sections['negative_dc'] = (len(vectors), len(vectors) + 8000)
vectors += [(-32768, 1, 128)] * 8000
sections['alternating'] = (len(vectors), len(vectors) + 8000)
vectors += [(32767 if n & 1 else -32768, 1, 128) for n in range(8000)]
sections['random_control'] = (len(vectors), len(vectors) + 4000)
vectors += [(rng.randrange(-32768,32768), rng.randrange(2), rng.randrange(512)) for _ in range(4000)]
sections['settled_bypass'] = (len(vectors), len(vectors) + 1200)
vectors += [(rng.randrange(-32768,32768),0,128) for _ in range(1200)]
vectors += [(0,1,64)] * 40000
sections['reference'] = (len(vectors), len(vectors) + 72000)
for n in range(72000):
    local = n % 12000
    freq = (261.625565,329.627557,391.995436,523.251131,440,293.664768)[n // 12000]
    t = local / FS
    value = int(10500 * math.exp(-8*t) *
                (math.sin(2*math.pi*freq*t) + .25*math.sin(4*math.pi*freq*t)))
    vectors.append((value,1,64))

(HERE / 'fx_vectors.txt').write_text(''.join(f'{x} {e} {w}\n' for x,e,w in vectors), encoding='ascii')
if not (HERE / 'work_fx').exists():
    run('vlib.exe',['work_fx'])
run('vlog.exe',['-vlog01compat','-work','work_fx',
    str(LAB / 'src/short_room_reverb.v'),str(LAB / 'src/vibrato_factor.v'),
    str(HERE / 'short_room_tb.v'),str(HERE / 'vibrato_tb.v'),str(HERE / 'short_room_fault_tb.v')])
for top,marker in (('short_room_tb','SHORT_ROOM_TB_PASS'),('vibrato_tb','VIBRATO_TB_PASS'),
                   ('short_room_fault_tb','SHORT_ROOM_FAULT_TB_PASS')):
    generic=[f'-gFRAME_CLOCKS={args.frame_clocks}'] if top=='short_room_tb' else []
    log=run('vsim.exe',['-c','-lib','work_fx',top,*generic,'-l',f'{top}_transcript.log',
                        '-do','run -all; quit -f'])
    if marker not in log:
        raise RuntimeError(log[-6000:])
    print(next(line for line in log.splitlines() if marker in line))

buffers=[[0]*length for length in (601,733,887,1091)]
positions=[0]*4
wet_state=0
rendered=[]
for n,line in enumerate((HERE / 'fx_output.txt').read_text().splitlines()):
    row,ready,wet,left,right,latency=map(int,line.split())
    x,enabled,requested=vectors[n]
    if n==sections['reference'][0]:
        assert all(value==0 for buffer in buffers for value in buffer), 'Reference has stale tail'
    target=min(128,requested) if enabled else 0
    wet_state = wet_state + (target>wet_state) - (target<wet_state) if ready else 0
    assert row==n and wet==wet_state and latency==24, (n,'frame/control')
    delayed=[]
    for i,buffer in enumerate(buffers):
        old=buffer[positions[i]] if ready else 0
        delayed.append(old)
        if ready:
            buffer[positions[i]]=trunc(x,4)+trunc(3*old,4)
            assert -32768<=buffer[positions[i]]<=32767
            positions[i]=(positions[i]+1)%len(buffer)
    a,b,c,d=delayed
    wl=trunc(3*a+2*b+c+2*d,8)
    wr=trunc(a+2*b+3*c+2*d,8)
    expected=(x+trunc((wl-x)*wet,256),x+trunc((wr-x)*wet,256))
    assert (left,right)==expected, (n,(left,right),expected)
    rendered.append((left,right))
assert len(rendered)==len(vectors)
for n in range(*sections['bypass']):
    assert rendered[n]==(vectors[n][0],)*2
start,end=sections['settled_bypass']
assert all(rendered[n]==(vectors[n][0],)*2 for n in range(start+128,end))
start,end=sections['impulse']
assert all(rendered[n]==(0,0) for n in range(start+1,start+601))
assert rendered[start+601][0] != rendered[start+601][1]
assert max(abs(v) for pair in rendered[end-1000:end] for v in pair)<10
assert max(abs(v) for pair in rendered for v in pair)<=32768
print(f'FX_ORACLE_PASS {len(vectors)} frames exact; stereo impulse, decay, DC, full-scale, bypass')

phase=0
effective=0
factor=65536
increments=[698,1047,1396,1745,2094,2443,2792,3141]
for line in (HERE / 'vibrato_output.txt').read_text().splitlines():
    n,enabled,depth,speed,actual,actual_depth=map(int,line.split())
    p=phase>>15
    triangle=383-p if p>=256 else p-128
    target=65536+(triangle*effective//4)
    factor+=max(-16,min(16,target-factor))
    depth_target=min(depth,64) if enabled else 0
    effective+=(depth_target>effective)-(depth_target<effective)
    phase=(phase+increments[speed])&0xffffff
    assert (actual,actual_depth)==(factor,effective),(n,'vibrato',actual,factor)
print('VIBRATO_ORACLE_PASS 200000 frames exact; frequencies=2..9 Hz, clamp, slew, return to unity')

reference_start,reference_end=sections['reference']
for name,channels in (
    ('short_room_dry.wav',[(vectors[n][0],)*2 for n in range(reference_start,reference_end)]),
    ('short_room_wet.wav',rendered[reference_start:reference_end]),
    ('short_room_impulse.wav',rendered[slice(*sections['impulse'])]),
):
    with wave.open(str(HERE / name),'wb') as stream:
        stream.setnchannels(2);stream.setsampwidth(2);stream.setframerate(round(FS))
        stream.writeframes(b''.join(struct.pack('<hh',*pair) for pair in channels))
print('RTL reference WAVs written under project/audio_fx_lab/sim (48,077 Hz)')
assert source_hashes=={path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                      for path in (LAB / 'src').glob('*.v')}, 'Source changed during verification'
record={'role':'A','board_tested':False,'sample_rate_hz':FS,
        'frame_spacing_clocks':args.frame_clocks,'output_latency_clocks':24,
        'effect_frames_checked':len(vectors),'vibrato_frames_checked':200000,
        'reference_source':'synthetic harmonic melody, effect rendered by real RTL',
        'exact_integer_oracle_pass':True,'bypass_pass':True,'stereo_impulse_pass':True,
        'full_scale_dc_bounds_pass':True,'tail_decay_pass':True,'source_sha256':source_hashes}
(LAB / 'sim_validation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
