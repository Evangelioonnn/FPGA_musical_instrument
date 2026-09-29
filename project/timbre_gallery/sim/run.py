"""Compile the same source list as the board project, then run pure RTL benches."""
from pathlib import Path
import argparse,subprocess,re,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent
PROJECT=HERE.parent/'variants/timbre_gallery_v1/timbre_gallery_v1.gprj'
ap=argparse.ArgumentParser();ap.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem')
ap.add_argument('--benches',default='gallery_equivalence_tb,gallery_math_tb,gallery_events_tb,gallery_board_tb')
ap.add_argument('--no-compile',action='store_true');args=ap.parse_args()
def run(tool,opts):
    r=subprocess.run([str(Path(args.modelsim)/tool),*opts],cwd=HERE,capture_output=True,text=True,errors='replace')
    log=r.stdout+'\n'+r.stderr
    if r.returncode or re.search(r'\*\* (Error|Fatal)',log):
        print(log,flush=True);raise RuntimeError(tool+' failed')
    return log
if not args.no_compile:
    if not (HERE/'work_gallery').exists():run('vlib.exe',['work_gallery'])
    sources=[str((PROJECT.parent/f.attrib['path']).resolve()) for f in ET.parse(PROJECT).iter('File') if f.attrib['type']=='file.verilog']
    sources += [str((HERE.parents[1]/'audio_output_lab/src'/name).resolve()) for name in
                ('output_bank.v','output_shared_tone.v')]
    sources += [str((HERE.parents[1]/'audio_palette_lab/src'/name).resolve()) for name in
                ('palette_slot.v','palette_tone_state.v')]
    sources += [str(p.resolve()) for p in HERE.glob('*.v')]
    log=run('vlog.exe',['-vlog01compat','-work','work_gallery',*sources])
    (HERE/'compile.log').write_text(log,encoding='utf-8');print('GALLERY_COMPILE_PASS',flush=True)
for name in args.benches.split(','):
    log=run('vsim.exe',['-c','-lib','work_gallery',name,'-l',name+'_transcript.log',
        '-wlf',name+'.wlf','-do','run -all; quit -f'])
    (HERE/(name+'.log')).write_text(log,encoding='utf-8')
    if name.upper()+'_PASS' not in log:print(log);raise RuntimeError(name+' missing PASS')
    print(next(line for line in log.splitlines() if name.upper()+'_PASS' in line),flush=True)
