"""Render actual RTL PCM, with verified ROM, unchanged gains and source hashes."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse
import array
import hashlib
import importlib.util
import json
import re
import subprocess
import wave
import xml.etree.ElementTree as ET

LAB=Path(__file__).resolve().parents[1];ROOT=LAB.parents[1];SIM=LAB/'sim'
parser=argparse.ArgumentParser()
parser.add_argument('--pluck',type=int,choices=[12,16],default=12)
parser.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--jobs',type=int,choices=[1,2,3],default=2)
args=parser.parse_args()
variant=LAB/'variants'/f'stream{args.pluck}'
sources=[(variant/x.attrib['path']).resolve() for x in ET.parse(variant/f'stream{args.pluck}.gprj').iter('File')
         if x.attrib['type']=='file.verilog']
sources += [SIM/'v2_render_tb.v']
inputs=sources+[Path(__file__).resolve(),variant/f'stream{args.pluck}.gprj']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
hashes={p.relative_to(ROOT).as_posix():sha(p) for p in inputs}
helper=importlib.util.spec_from_file_location('rom_helper',LAB.parent/'audio_core_v1/tools/sim_rom.py')
module=importlib.util.module_from_spec(helper);helper.loader.exec_module(module)
rom=module.prepare_and_verify(args.modelsim)
sources=[Path(rom['replacement_source']) if p.name=='palette_sine.v' else p for p in sources]
library=f'work_v2_render_p{args.pluck}'
def run(tool,options):
    result=subprocess.run([str(Path(args.modelsim)/tool),*options],cwd=SIM,capture_output=True,text=True,errors='replace')
    log=result.stdout+'\n'+result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)',log):raise RuntimeError(log[-4000:])
    return log
if not (SIM/library).exists():run('vlib.exe',[library])
run('vlog.exe',['-vlog01compat','-work',library,*map(str,sources)])
def render(scene):
    log_name=f'v2_render_p{args.pluck}_scene{scene}.log'
    text=run('vsim.exe',['-c','-lib',library,'v2_render_tb',f'-gP={args.pluck}',f'-gSCENE={scene}',
                        '-l',log_name,'-do','onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f'])
    marker=next((s for s in text.splitlines() if 'V2_RENDER_TB_PASS' in s),None)
    if marker is None:raise RuntimeError('Missing preview PASS')
    rows=[tuple(map(int,s.split())) for s in (SIM/f'v2_preview_p{args.pluck}_scene{scene}.txt').read_text().splitlines()]
    if not rows or any(len(row)!=2 for row in rows):raise RuntimeError('Malformed PCM capture')
    output=LAB/'audio'/f'v2_{scene:02d}_preview.wav'
    output.parent.mkdir(exist_ok=True)
    pcm=array.array('h',(v for row in rows for v in row))
    with wave.open(str(output),'wb') as wav:
        wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(round(50000000/1040));wav.writeframes(pcm.tobytes())
    record={'scene':scene,'frames':len(rows),'peak':max(abs(v) for row in rows for v in row),
            'sha256':sha(output),'file':output.relative_to(ROOT).as_posix(),'marker':marker}
    print(marker,flush=True);return record
with ThreadPoolExecutor(max_workers=args.jobs) as pool:records=list(pool.map(render,range(7)))
if hashes!={p.relative_to(ROOT).as_posix():sha(p) for p in inputs}:raise RuntimeError('Render sources changed')
record={'pluck_capacity':args.pluck,'master_q16':65536,'normalised':False,
        'harmonic_per_note_gain':'1/4 of V1','pluck_per_note_gain':'unchanged',
        'actual_frame_clocks':1040,'sample_rate_exact_hz':50000000/1040,
        'order':['piano0','Warm pluck2','bell3','Drive lead4','custom5','piano32 repeats','Lead + room/vibrato'],
        'sources':hashes,'scenes':records,'ROM_exhaustive_equivalence':rom['result'] if 'result' in rom else True}
(LAB/'audio/preview.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
