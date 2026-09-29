from pathlib import Path
import argparse
import array
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import re
import subprocess
import time
import wave
import xml.etree.ElementTree as ET

LAB=Path(__file__).resolve().parents[1]
ROOT=LAB.parents[1]
HERE=LAB/'sim'
parser=argparse.ArgumentParser()
parser.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--fast-rom',action='store_true',help='Use an exhaustively verified sine ROM simulation model')
parser.add_argument('--jobs',type=int,default=3,choices=range(1,7),
                    help='Parallel independent scenes; 1 retains the continuous six-scene sequence')
args=parser.parse_args()
started=time.time()


def run(tool, options):
    result=subprocess.run([str(Path(args.modelsim)/tool),*options],cwd=HERE,
                          capture_output=True,text=True,errors='replace')
    text=result.stdout+'\n'+result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)',text): raise RuntimeError(text[-4000:])
    return text


rom_record=None
legacy_reference=None
if args.fast_rom:
    from sim_rom import prepare_and_verify
    rom_record=prepare_and_verify(args.modelsim)
    legacy_path=HERE/'audio_preview_0_1.txt'
    if legacy_path.exists():
        legacy_reference=legacy_path.read_bytes()
library='work_render_parallel' if args.jobs>1 else ('work_render_fast' if args.fast_rom else 'work_render')
suffix='_fastrom' if args.fast_rom else ''
if not (HERE/library).exists():run('vlib.exe',[library])
sources=[str((LAB/x.attrib['path']).resolve()) for x in ET.parse(LAB/'audio_core.gprj').iter('File')
         if x.attrib['type']=='file.verilog']
inputs=[Path(p) for p in sources]+[LAB/'audio_core.gprj',HERE/'audio_render_tb.v',Path(__file__).resolve()]
if args.fast_rom:
    inputs += [LAB/'tools/sim_rom.py',HERE/'sine_rom_equivalence_tb.v']
source_hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
if args.fast_rom:
    if sum(Path(p).name=='palette_sine.v' for p in sources)!=1:
        raise RuntimeError('Expected exactly one sine ROM source in the synthesis project')
    sources=[str(rom_record['replacement_source']) if Path(p).name=='palette_sine.v' else p for p in sources]
run('vlog.exe',['-vlog01compat','-work',library,*sources,str(HERE/'audio_render_tb.v')])
(HERE/'work_rom_data').mkdir(exist_ok=True)
markers=[]
logs=[]
jobs=[]
def render_job(fast,short,scene=-1):
    scene_suffix=f'_scene{scene}' if scene>=0 else ''
    log_name=f'render_{fast}_{short}{suffix}{scene_suffix}.log'
    text=run('vsim.exe',['-c','-lib',library,'audio_render_tb',f'-gFAST={fast}',f'-gSHORT={short}',
                        f'-gROM_FAST={int(args.fast_rom)}',f'-gSCENE={scene}',
                        '-wlf',f'work_rom_data/render_{fast}_{short}{scene_suffix}.wlf',
                        '-l',log_name,'-do','run -all; quit -f'])
    marker=next((s for s in text.splitlines() if 'AUDIO_RENDER_TB_PASS' in s),None)
    if marker is None:raise RuntimeError('Missing render PASS')
    print(marker,flush=True)
    return {'fast':fast,'short':short,'scene':scene,'log':log_name,'marker':marker,
            'pcm':f'audio_preview_{fast}_{short}{suffix}{scene_suffix}.txt'}
for fast,short in ((0,1),(1,1)):
    job=render_job(fast,short)
    jobs.append(job)
    if args.fast_rom and fast==0 and short==1 and legacy_reference is not None:
        if (HERE/'audio_preview_0_1_fastrom.txt').read_bytes()!=legacy_reference:
            raise RuntimeError('Fast ROM default PCM differs from existing nominal original-ROM reference')
        rom_record['full_audio_chain_verified']=True
        rom_record['chain_equivalence_frames']=950
        rom_record['chain_equivalence_scope']='default piano only; original-ROM nominal vs array-ROM nominal'
        print('FAST_ROM_CHAIN_PASS 950 frames equal to existing original-ROM nominal reference',flush=True)
if (HERE/f'audio_preview_0_1{suffix}.txt').read_bytes()!=(HERE/f'audio_preview_1_1{suffix}.txt').read_bytes():
    raise RuntimeError('Accelerated default PCM differs from nominal1040 clock schedule')
continuous_reference=None
reference_path=HERE/f'audio_preview_1_0{suffix}.txt'
if args.jobs>1 and reference_path.exists():
    prefix=reference_path.read_text().splitlines()[:24654]
    if len(prefix)==24654 and all(len(line.split())==2 for line in prefix):
        continuous_reference=[tuple(map(int,line.split())) for line in prefix]
        print('CONTINUOUS_REFERENCE_CAPTURED first 24654 PCM frames',flush=True)
if args.jobs>1:
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures=[pool.submit(render_job,1,0,scene) for scene in range(6)]
        jobs.extend(future.result() for future in futures)
else:
    jobs.append(render_job(1,0))
rows=[]
scene_frames=[]
for job in jobs:
    logs.append(job['log']);markers.append(job['marker'])
    if job['short']:
        continue
    samples=[tuple(map(int,line.split())) for line in (HERE/job['pcm']).read_text().splitlines()]
    if any(len(sample)!=2 for sample in samples):
        raise RuntimeError('Expected two PCM channels in every rendered frame')
    if job['scene']==0 and continuous_reference is not None:
        if samples!=continuous_reference:
            raise RuntimeError('Independent first scene differs from the continuous RTL scene')
        print('PARALLEL_SCENE_EQUIVALENCE_PASS 24654 first-scene frames',flush=True)
    rows.extend(samples);scene_frames.append(len(samples))
pcm=array.array('h',(v for row in rows for v in row))
output=LAB/'audio/five_timbre_and_room_preview.wav'
output.parent.mkdir(exist_ok=True)
with wave.open(str(output),'wb') as wav:
    wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(round(50000000/1040));wav.writeframes(pcm.tobytes())
record={'frames':len(rows),'peak':max(abs(v) for row in rows for v in row),
        'sample_rate_exact_hz':50000000/1040,'wav_rate_hz':round(50000000/1040),
        'normalised':False,'default_master_gain_q16':8249,
        'preview_order':[0,2,3,4,5,'Drive lead + room/vibrato'],
        'nominal_vs_accelerated_default_pcm_equal':True,'markers':markers,
        'render_logs':logs,'fast_rom':args.fast_rom,
        'render_jobs':jobs,'parallel_scene_jobs':args.jobs,'scene_frames':scene_frames,
        'scene_reset_mode':'independent reset per scene' if args.jobs>1 else 'continuous sequence with panic between presets',
        'continuous_first_scene_pcm_equal':continuous_reference is not None if args.jobs>1 else None,
        'original_rom_nominal_reference_equal':legacy_reference is not None if args.fast_rom else None,
        'original_rom_nominal_reference_sha256':hashlib.sha256(legacy_reference).hexdigest() if legacy_reference is not None else None,
        'sine_rom_equivalence':rom_record,
        'sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
if source_hashes!={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}:
    raise RuntimeError('A rendering source changed during simulation')
if rom_record is not None:
    for field in ('replacement_source','reference_source','rom_data','bench_source'):
        if field in rom_record:
            rom_record[field]=Path(rom_record[field]).relative_to(ROOT).as_posix()
record['source_sha256']=source_hashes
record['elapsed_seconds']=round(time.time()-started,2)
(LAB/'audio/preview.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(f'{output}: {len(rows)} frames, peak={record["peak"]}',flush=True)
