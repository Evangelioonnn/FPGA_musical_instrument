from pathlib import Path
import argparse
import json
import re
import subprocess
import xml.etree.ElementTree as ET

HERE=Path(__file__).resolve().parent
LAB=HERE.parent
parser=argparse.ArgumentParser()
parser.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--previews',action='store_true')
parser.add_argument('--preview-only',action='store_true')
parser.add_argument('--extra-only',action='store_true')
args=parser.parse_args()


def run(tool, options):
    result=subprocess.run([str(Path(args.modelsim)/tool),*options],cwd=HERE,
        capture_output=True,text=True,errors='replace')
    log=result.stdout+'\n'+result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)',log):
        raise RuntimeError(tool+' failed:\n'+log[-6000:])
    return log


library=HERE/'work_poly'
if not library.exists():run('vlib.exe',['work_poly'])
directory=LAB/'variants/piano16'
sources=[str((directory/f.attrib['path']).resolve()) for f in ET.parse(directory/'piano16.gprj').iter('File')
         if f.attrib['type']=='file.verilog']
sources += [str(HERE/name) for name in ('poly_core_tb.v','poly_preview_tb.v','poly_board_tb.v','poly_equivalence_tb.v')]
sources.append(str(LAB.parent/'five_timbre_core/src/gallery_shared_tone.v'))
run('vlog.exe',['-vlog01compat','-work','work_poly',*sources])
results=[]
for voices,shift in ([] if args.extra_only or args.preview_only else [(8,0),(16,1),(32,2),(16,0),(32,0)]):
    log=run('vsim.exe',['-c','-lib','work_poly','poly_core_tb',f'-gN={voices}',f'-gSHIFT={shift}',
        '-l',f'poly_{voices}_{shift}.log','-do','run -all; quit -f'])
    marker=next((line for line in log.splitlines() if 'POLY_CORE_TB_PASS' in line),None)
    if not marker:raise RuntimeError('Missing PASS marker:\n'+log[-6000:])
    print(marker,flush=True)
    results.append(marker)
for voices,shift in ([] if args.preview_only else [(16,1),(32,2)]):
    log=run('vsim.exe',['-c','-lib','work_poly','poly_board_tb',f'-gN={voices}',f'-gSHIFT={shift}',
        '-l',f'poly_board_{voices}.log','-do','run -all; quit -f'])
    marker=next((line for line in log.splitlines() if 'POLY_BOARD_TB_PASS' in line),None)
    if not marker:raise RuntimeError('Missing board PASS:\n'+log[-6000:])
    print(marker,flush=True);results.append(marker)
for fast in ([] if args.preview_only else (0,1)):
    log=run('vsim.exe',['-c','-lib','work_poly','poly_preview_tb','-gN=32','-gSHIFT=2',
        f'-gFAST={fast}','-gSHORT=1','-l',f'poly_cadence_{fast}.log','-do','run -all; quit -f'])
    marker=next((line for line in log.splitlines() if 'POLY_PREVIEW_TB_PASS' in line),None)
    if not marker:raise RuntimeError('Missing cadence PASS:\n'+log[-6000:])
    results.append(marker)
if not args.preview_only:
    assert (HERE/'poly_preview_32_2_0_1.txt').read_bytes()==(HERE/'poly_preview_32_2_1_1.txt').read_bytes()
    print('POLY_CADENCE_EQUIVALENCE_PASS 403 PCM samples actual1040 == accelerated520',flush=True)
    results.append('POLY_CADENCE_EQUIVALENCE_PASS actual1040 == accelerated520')
    log=run('vsim.exe',['-c','-lib','work_poly','poly_equivalence_tb',
        '-l','poly_equivalence.log','-do','run -all; quit -f'])
    marker=next((line for line in log.splitlines() if 'POLY_EQUIVALENCE_TB_PASS' in line),None)
    if not marker:raise RuntimeError('Missing equivalence PASS:\n'+log[-6000:])
    print(marker,flush=True);results.append(marker)
if args.previews:
    for voices,shift in [(8,0),(16,1),(32,2)]:
        log=run('vsim.exe',['-c','-lib','work_poly','poly_preview_tb',f'-gN={voices}',f'-gSHIFT={shift}',
            '-l',f'poly_preview_{voices}.log','-do','run -all; quit -f'])
        marker=next((line for line in log.splitlines() if 'POLY_PREVIEW_TB_PASS' in line),None)
        if not marker:raise RuntimeError('Missing preview PASS:\n'+log[-6000:])
        print(marker,flush=True);results.append(marker)
(LAB/'results').mkdir(exist_ok=True)
result_path=LAB/'results/simulation.json'
if (args.extra_only or args.preview_only) and result_path.exists():
    previous=json.loads(result_path.read_text())['pass_markers']
    if args.extra_only:
        previous=[line for line in previous if 'POLY_CORE_TB_PASS' in line]
    else:
        previous=[line for line in previous if 'POLY_PREVIEW_TB_PASS' not in line or 'SHORT=1' in line]
    results=previous+results
result_path.write_text(json.dumps({'pass_markers':results},indent=2)+'\n',encoding='ascii')
